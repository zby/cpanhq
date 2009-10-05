#!/usr/bin/perl

use strict;
use warnings;

use lib 'lib';

use Path::Class::Dir;
use Path::Class::File;
use Parse::CPAN::Whois;
use Parse::CPAN::Packages;
use DateTime;
use File::Next;
use LWP::Simple;
use Getopt::Long;
use Try::Tiny;

use CPAN::Mini;
use Archive::Extract;
use YAML::XS;
use ExtUtils::MM_Unix;

require CPANHQ;

$|++;

my $scan_packages = 1;
my $scan_releases = 1;

my $filter;
GetOptions(
    "filter=s" => \$filter,
    "scan-packages!" => \$scan_packages,
    "scan-releases!" => \$scan_releases,
);   

if (defined($filter))
{
    $filter = qr{$filter};
}
else
{
    $filter = qr{.}ms;
}

my %config = CPAN::Mini->read_config;
my $cpan_base = $config{'local'};

$cpan_base = Path::Class::Dir->new( $cpan_base );

my $authors_xml_fn = $cpan_base->file( qw( authors 00whois.xml ) )->stringify;

print "Fetching Authors...\n";

if ((! -e $authors_xml_fn) || ((-M $authors_xml_fn) >= 1))
{
    getstore("http://www.cpan.org/authors/00whois.xml", $authors_xml_fn);
}

print "Loading Authors...\n";

my $authors = Parse::CPAN::Whois->new( $authors_xml_fn );
my $author_rs = CPANHQ->model('DB::Author');

print "Loading Packages...\n";
my $packages = Parse::CPAN::Packages->new( $cpan_base->file( qw( modules 02packages.details.txt.gz ) )->stringify );
my $dist_rs = CPANHQ->model('DB::Distribution');
my $release_rs = CPANHQ->model('DB::Release');
my $package_rs = CPANHQ->model('DB::Package');

if ($scan_releases)
{
    scan_releases();
}

if ($scan_packages)
{
    scan_packages();
}

{
    my $to_path = CPANHQ->config->{'archive_extract_path'};
    my $file_rs = CPANHQ->model('DB::ReleaseFile');
    while ( my $file = $file_rs->next ){
        my ( $package_id, $abstract );
        if( $file->filename =~ /lib\/(.*)\.pm\z/ ){
            my $p_name = $1;
            $p_name =~ s/$to_path//;
            $p_name =~ s{/}{::}g;
            my $package = $file->release->distribution->packages->search( { name => $p_name } )->first;
            next if !$package;
            $file->package_id( $package->id );
            my $mm =  bless { DISTNAME => $p_name }, 'ExtUtils::MM_Unix';
            $file->abstract( $mm->parse_abstract( File::Spec->catfile( $to_path, $file->filename ) ) );
            $file->update;
        }
    }
}


sub scan_releases
{
    my $file_it = File::Next::files( { follow_symlinks => 0 }, $cpan_base->subdir( qw( authors id ) ) );

    print "Scanning Files...\n";
    my $count = 0;
    while ( defined ( my $file = $file_it->() ) ) {
        next if $file =~ m{/CHECKSUMS$};
        next if $file !~ $filter;
        ( my $prefix = $file ) =~ s{^$cpan_base/}{};
        my $dist = $packages->distribution_from_prefix( $prefix );
        next unless $dist && defined $dist->version;

        $count++;
        printf "\r%-75s", join( ' ', $dist->dist, $dist->version ) . ' by ' . $dist->cpanid;

        # handle dist author
        my $author = $authors->author( $dist->cpanid );
        my $db_author = $author_rs->update_or_create( { cpanid => $author->pauseid, email => ($author->email || ""), name => $author->name, homepage => $author->homepage, }, { key => 'author_cpanid' } );

        # handle dist
        my $db_dist = $dist_rs->find_or_create( { name => $dist->dist }, { key => 'distribution_name' } );

        # handle release
        my $stat = Path::Class::File->new( $file )->stat;
        my $db_release = $release_rs->update_or_create( {
            distribution_id => $db_dist->id,
            version => $dist->version,
            author_id => $db_author->id,
            path => $dist->prefix,
            developer_release => ( $dist->maturity eq 'developer' ? 1 : 0 ),
            size => $stat->size,
            release_date => DateTime->from_epoch( epoch => $stat->mtime ),
        }, { key => 'release_distribution_id_version' } );
       
        try {
            _process_meta_yml( $db_release );
        }
        catch { 
            warn "caught error: $_";
        };
    }
    print "\n$count Releases Indexed\n";
}
sub _arc_path {
    my $release = shift;
    my %config = CPAN::Mini->read_config;
    my $minicpan_path = $config{'local'};

    my $dist_path = $release->path();
    my $arc_path =
        File::Spec->catfile(
            $minicpan_path,
            $dist_path,
        );

    if (! -e $arc_path)
    {
        die "Archive path '$arc_path' not found";
    }
    return $arc_path;
}


sub _extract_files {
    my $release = shift;

    my $ae = Archive::Extract->new( archive => _arc_path( $release ) );

    my $to_path = CPANHQ->config->{'archive_extract_path'};

    my $ok = $ae->extract( to => $to_path, )
        or die $ae->error();

    my $extracted_files = $ae->files();

    my $files_rs = $release->files_rs();

    my $dir = $release->distribution->name;
    $dir =~ s/::/-/g;
    $dir = File::Spec->catdir( $dir . '-' . $release->version, 'lib' );

    my $package_rs = $release->result_source->schema->resultset( 'Package' );
    foreach my $f (@$extracted_files) {
        my ( $package_id, $abstract );
        if( $f =~ /$dir\/(.*)\.pm\z/ ){
            my $p_name = $1;
            $p_name =~ s/$to_path//;
            $p_name =~ s{/}{::}g;
            my $package = $package_rs->find_or_create( { name => $p_name, distribution_id => $release->distribution->id } );
            $package_id = $package->id;
            my $mm =  bless { DISTNAME => $p_name }, 'ExtUtils::MM_Unix';
            $abstract = $mm->parse_abstract( File::Spec->catfile( $to_path, $f ) );
        }

        $files_rs->find_or_create(
            {
                release => $release,
                filename => $f,
                package_id => $package_id,
                abstract => $abstract,
            },
        );
    }
    return $extracted_files;
}


sub _get_meta_yml {
    my $release = shift;
    
    my $files_rs = $release->files_rs();
    if( ! $files_rs->count ){
        _extract_files( $release );
    }

    my $meta_yml_file = $files_rs->search( { filename => { like => '%META.yml' } } )->first;

    if (!defined ($meta_yml_file))
    {
        my $arc_path = _arc_path( $release );
        die "Could not find META.yml in archive '$arc_path'";
    }

    my $meta_yml_full_path = File::Spec->catfile(
        CPANHQ->config->{'archive_extract_path'}, $meta_yml_file->filename
    );

    my ($yaml) = YAML::XS::LoadFile($meta_yml_full_path);

    return $yaml;
}


sub _process_meta_yml {
    my $release = shift;

    my $meta_yml = _get_meta_yml( $release );

    if (my $license = $meta_yml->{'license'}) {
        $release->license(
            $release->result_source->schema->resultset('License')->find(
                {
                    string_id => $license,
                }
            )
        );
    }

    if (defined(my $abstract = $meta_yml->{'abstract'})) {
        $release->abstract($abstract);
    }

    if (defined(my $resources = $meta_yml->{'resources'}))
    {
        my %res_to_db =
        (
            homepage => "homepage",
            MailingList => "mailing_list",
            repository => "vcs_repository",
        );

        while (my ($res, $db_key) = each(%res_to_db))
        {
            if (defined(my $res_val = $resources->{$res})) {
                $release->$db_key($res_val);
            }
        }
    }

    if (defined(my $keywords = $meta_yml->{'keywords'})) {
        # Doing it in a pretty dumb and not-so-DBIx-Class-y way now
        # until I figure out a better way to do it, if one exists.
        # TODO : Delete all the previous author-tags.
        foreach my $tag_string (@$keywords)
        {
            my $tag = $release->result_source->schema->resultset('Keyword')
                           ->find_or_create({string_id => $tag_string})
                           ;
            
            #$release->result_source->schema
            #    ->resultset('AuthorDistributionKeyword')
            #    ->new({distribution => $release->distribution(), keyword => $tag})
            #    ->insert()
            #    ;
            $release->result_source->schema
                ->resultset('AuthorDistributionKeyword')
                ->find_or_create({distribution => $release->distribution(), keyword => $tag});
                
        }
    }

    if ( defined( my $deps = $meta_yml->{'requires'} ) ) {
        my @deps;
        if( ref $deps eq 'HASH' ){
            @deps = keys %$deps;
        }
        if( ! ref $deps ){
            @deps = $deps;
        }
        foreach my $dep_name (@deps) {
            $dep_name =~ s/::/-/g;
            my $dep =
            $release->result_source->schema->resultset('Distribution')
                ->find( { name => $dep_name } );
            next unless $dep;
            $release->result_source->schema->resultset('Requires')
                ->new( { dist_from => $release->distribution->id, dist_to => $dep->id, } )
                ->insert;
        }
    }
    $release->update();

    return;
}


sub scan_packages
{
    my $count = 0;

    PACKAGES_LOOP:
    foreach my $pkg_obj ($packages->packages()) {
        my $name = $pkg_obj->package();
        my $dist = $pkg_obj->distribution()->dist();
        
        if ($name !~ $filter)
        {
            next PACKAGES_LOOP;
        }
        printf "\r%-75s", "$name ($count)";
        my $db_package = $package_rs->find_or_create(
            { name => $name, },
            # { key => "name" }
        );

        $db_package->distribution(
            $dist_rs->find({name => $dist})
        );

        $db_package->update();

        $count++
    }
    print "\n$count Packages Indexed\n";
}
