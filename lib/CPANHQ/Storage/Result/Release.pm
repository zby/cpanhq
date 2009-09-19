package CPANHQ::Storage::Result::Release;

use strict;
use warnings;

=head1 NAME

CPANHQ::Storage::Result::Release - a class representing a CPANHQ release

=head1 SYNOPSIS

    my $schema = CPANHQ->model("DB");

    my $releases_rs = $schema->resultset('Release');

    my $module_build_release = $releases_rs->find({
        distribution_id => $schema->resultset('Distribution')->find(
            {
                name => "Module-Build",
            })->id(),
        version => "0.33",
    );

    # Prints "Module-Build"
    print $module_build_release->distribution()->name();

    print $module_build_release->release_date();

    # Prints "EWILHELM"
    print $module_build_release->author()->cpanid();

=head1 DESCRIPTION

This is the release schema class for L<CPANHQ>.

=head1 METHODS

=cut

use base qw( DBIx::Class );

use File::Spec;
use List::Util qw(first);
use File::Temp qw(tempdir);
use File::Spec;

use CPAN::Mini;
use Archive::Extract;
use YAML::XS;
use ExtUtils::MM_Unix;

use CPANHQ;

__PACKAGE__->load_components( qw( InflateColumn::DateTime Core ) );
__PACKAGE__->table( 'release' );
__PACKAGE__->add_columns(
    id => {
        data_type         => 'bigint',
        is_auto_increment => 1,
        is_nullable       => 0,
    },
    distribution_id => {
        data_type      => 'bigint',
        is_nullable    => 0,
        is_foreign_key => 1,
    },
    license_id => {
        data_type      => 'bigint',
        is_nullable    => 1,
        is_foreign_key => 1,
    },
    version => {
        data_type   => 'varchar',
        size        => 32,
        is_nullable => 1,
    },
    developer_release => {
        data_type     => 'boolean',
        default_value => 0,
        is_nullable   => 0,
    },
    path => {
        data_type   => 'varchar',
        size        => 255,
        is_nullable => 0,
    },
    size => {
        data_type   => 'bigint',
        is_nullable => 1,
    },
    author_id => {
        data_type      => 'bigint',
        is_nullable    => 0,
        is_foreign_key => 1,
    },
    release_date => {
        data_type   => 'datetime',
        is_nullable => 0,
    },
    meta_yml_was_procd => {
        data_type => 'boolean',
        default_value => 0,
        is_nullable => 0,
    },
    abstract => {
        data_type   => 'varchar',
        size        => 512,
        is_nullable => 1,
    },
    homepage => {
        data_type   => 'varchar',
        size        => 512,
        is_nullable => 1,
    },
    mailing_list => {
        data_type   => 'varchar',
        size        => 512,
        is_nullable => 1,
    },
    vcs_repository => {
        data_type   => 'varchar',
        size        => 1024,
        is_nullable => 1,
    },
);

__PACKAGE__->set_primary_key( qw( id ) );
__PACKAGE__->resultset_attributes( { order_by => [ 'release_date DESC' ] } );
__PACKAGE__->belongs_to(
    distribution => 'CPANHQ::Storage::Result::Distribution',
    'distribution_id'
);
__PACKAGE__->belongs_to( author => 'CPANHQ::Storage::Result::Author', 'author_id' );
__PACKAGE__->belongs_to( license => 'CPANHQ::Storage::Result::License', 'license_id' );
__PACKAGE__->add_unique_constraint( [ qw( distribution_id version ) ] );
__PACKAGE__->has_many(
    files => 'CPANHQ::Storage::Result::ReleaseFile',
    'release_id',
);

=head2 $release->name()

Returns the distribution name and version.

=cut

sub name {
    my $self = shift;
    return join( ' ', $self->distribution->name, $self->version || '' );
}

=head2 $release->_get_meta_yml()

Reads the META.yml associated with this release and returns it.

May throw an exception.

=cut

sub _arc_path {
    my $self = shift;
    my %config = CPAN::Mini->read_config;
    my $minicpan_path = $config{'local'};

    my $dist_path = $self->path();
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
    my $self = shift;

    my $ae = Archive::Extract->new( archive => $self->_arc_path );

    my $to_path = CPANHQ->config->{'archive_extract_path'};

    my $ok = $ae->extract( to => $to_path, )
        or die $ae->error();

    my $extracted_files = $ae->files();

    my $files_rs = $self->files_rs();

    my $dir = $self->distribution->name;
    $dir =~ s/::/-/g;
    $dir = File::Spec->catdir( $dir . '-' . $self->version, 'lib' );

    my $package_rs = $self->result_source->schema->resultset( 'Package' );
    foreach my $f (@$extracted_files) {
        my ( $package_id, $abstract );
        if( $f =~ /$dir\/(.*)\.pm\z/ ){
            my $p_name = $1;
            $p_name =~ s/$to_path//;
            $p_name =~ s{/}{::}g;
            my $package = $package_rs->find_or_create( { name => $p_name, distribution_id => $self->distribution->id } );
            $package_id = $package->id;
            my $mm =  bless { DISTNAME => $p_name }, 'ExtUtils::MM_Unix';
            $abstract = $mm->parse_abstract( File::Spec->catfile( $to_path, $f ) );
        }

        $files_rs->find_or_create(
            {
                release => $self,
                filename => $f,
                package_id => $package_id,
                abstract => $abstract,
            },
        );
    }
    return $extracted_files;
}


sub _get_meta_yml {
    my $self = shift;
    
    my $files_rs = $self->files_rs();
    if( ! $files_rs->count ){
        $self->_extract_files;
    }

    my $meta_yml_file = $files_rs->search( { filename => { like => '%META.yml' } } )->first;

    if (!defined ($meta_yml_file))
    {
        my $arc_path = $self->_arc_path;
        die "Could not find META.yml in archive '$arc_path'";
    }

    my $meta_yml_full_path = File::Spec->catfile(
        CPANHQ->config->{'archive_extract_path'}, $meta_yml_file->filename
    );

    my ($yaml) = YAML::XS::LoadFile($meta_yml_full_path);

    return $yaml;
}

=head2 $self->_process_meta_yml()

Processes the META.yml (as returned by _get_meta_yml() ) and fills the
appropriate fields in the database.

=cut

sub _process_meta_yml {
    my $self = shift;

    if ($self->meta_yml_was_procd() ) {
        return;
    }

    my $meta_yml = $self->_get_meta_yml();

    $self->meta_yml_was_procd(1);

    if (my $license = $meta_yml->{'license'}) {
        $self->license(
            $self->result_source->schema->resultset('License')->find(
                {
                    string_id => $license,
                }
            )
        );
    }

    if (defined(my $abstract = $meta_yml->{'abstract'})) {
        $self->abstract($abstract);
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
                $self->$db_key($res_val);
            }
        }
    }

    if (defined(my $keywords = $meta_yml->{'keywords'})) {
        # Doing it in a pretty dumb and not-so-DBIx-Class-y way now
        # until I figure out a better way to do it, if one exists.
        # TODO : Delete all the previous author-tags.
        foreach my $tag_string (@$keywords)
        {
            my $tag = $self->result_source->schema->resultset('Keyword')
                           ->find_or_create({string_id => $tag_string})
                           ;
            
            #$self->result_source->schema
            #    ->resultset('AuthorDistributionKeyword')
            #    ->new({distribution => $self->distribution(), keyword => $tag})
            #    ->insert()
            #    ;
            $self->result_source->schema
                ->resultset('AuthorDistributionKeyword')
                ->find_or_create({distribution => $self->distribution(), keyword => $tag});
                
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
            $self->result_source->schema->resultset('Distribution')
                ->find( { name => $dep_name } );
            next unless $dep;
            $self->result_source->schema->resultset('Requires')
                ->new( { dist_from => $self->distribution->id, dist_to => $dep->id, } )
                ->insert;
        }
    }
    $self->update();

    return;
}

=head1 SEE ALSO

L<CPANHQ::Storage>, L<CPANHQ>, L<DBIx::Class>

=head1 AUTHOR

Brian Cassidy E<lt>bricas@cpan.orgE<gt>

Shlomi Fish L<http://www.shlomifish.org/> (who places all his contributions
and modifications under the public domain -
L<http://creativecommons.org/license/zero> )

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
