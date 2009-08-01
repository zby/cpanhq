package CPANHQ::Storage::Package;

use strict;
use warnings;

use File::Spec;
use YAML::XS ();

=head1 NAME

CPANHQ::Storage::Package - a class representing a CPAN package/namespace

=head1 SYNOPSIS
      
    my $schema = CPANHQ->model("DB");

    my $packages_rs = $schema->resultset('Package');

    my $package = $packages_rs->find({
        name => "Acme::Colour",
        });

    print $package->id();

=head1 DESCRIPTION

This is the package/namespace schema class for L<CPANHQ>. Essentially,
every CPAN distribution may contain several packages. The packages to their
owning distribution map is found at C<02packages.details.txt.gz>.

=head1 METHODS

=cut

use base qw( DBIx::Class );

__PACKAGE__->load_components( qw( Core ) );
__PACKAGE__->table( 'package' );
__PACKAGE__->add_columns(
    id => {
        data_type         => 'bigint',
        is_auto_increment => 1,
        is_nullable       => 0,
    },
    name => {
        data_type   => 'varchar',
        size        => 255,
        is_nullable => 0,
    },
    distribution_id => {
        data_type => 'bigint',
        is_nullable => 1,
    },
);

__PACKAGE__->set_primary_key( qw( id ) );
__PACKAGE__->resultset_attributes( { order_by => [ 'name' ] } );
__PACKAGE__->add_unique_constraint( [ 'name' ] );
__PACKAGE__->belongs_to(
   distribution => 'CPANHQ::Storage::Distribution',
   'distribution_id'
);

my $mycpan_indexer_results = "$ENV{HOME}/minicpan-catalog/reports";

sub latest_release
{
    my $self = shift;

    return $self->distribution()->latest_release();
}

sub _calc_path_to_mycpan_yml_file
{
    my $self = shift;

    my $distribution = $self->distribution();

    my $release = $distribution->latest_release();

    my $fn_base = $distribution->name() . "-" . $release->version();

    my $yml_file = File::Spec->catfile(
        $mycpan_indexer_results,
        "success",
        $fn_base . ".yml",
    );

    return $yml_file;
}

sub _calc_mycpan_yml
{
    my $self = shift;

    my ($yaml) = YAML::XS::LoadFile(
        $self->_calc_path_to_mycpan_yml_file(),
    );

    return $yaml;
}

sub _quote_like_clause_ops
{
    my $self = shift;
    my $s = shift;

    $s =~ s/(%_\\)/\\$1/g;

    return $s;
}

sub get_html_path
{
    my $self = shift;

    my $yaml = $self->_calc_mycpan_yml();

    my $dist_file =
        $yaml->{'dist_info'}{'META.yml'}{'provides'}{$self->name()}{'file'}
        ;

    my $release = $self->latest_release;

    $release->_process_meta_yml();

    my $files_rs = $release->files_rs();

    my $matching_files_rs = $files_rs->search(
        {
            '-nest' => \[ 
                "LIKE(?, filename, ?)", 
                map { [ __DUMMY__ => $_ ] } (
                    ("%/" . $self->_quote_like_clause_ops($dist_file)), 
                    '\\'
                ) 
            ],
        }
    );
    
    my $path_record = $matching_files_rs->next();

    my $to_path = CPANHQ->config->{'archive_extract_path'};

    my $file_full_path = File::Spec->catfile(
        $to_path, $path_record->filename(),
    );

    return $file_full_path;
}

=head1 SEE ALSO

L<CPANHQ::Storage>, L<CPANHQ>, L<DBIx::Class>

=head1 AUTHOR

Shlomi Fish L<http://www.shlomifish.org/> .

=head1 LICENSE

This module is free software, available under the MIT X11 Licence:

L<http://www.opensource.org/licenses/mit-license.php>

Copyright by Shlomi Fish, 2009.

=cut

1;
