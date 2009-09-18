package CPANHQ::Storage::Result::ReleaseFile;

use strict;
use warnings;

use File::Spec;
use YAML::XS ();

=head1 NAME

CPANHQ::Storage::Result::Release - a class representing a file belonging to a
CPAN release.

=head1 SYNOPSIS
      
    my $schema = CPANHQ->model("DB");

    my $packages_rs = $schema->resultset('Package');

    my $package = $packages_rs->find({
        name => "Acme::Colour",
        });

    my $release = $package->distribution->latest_release();

    my $files_rs = $release->files_rs();

=head1 DESCRIPTION

This table contains a list of files in the release.

=head1 METHODS

=cut

use base qw( DBIx::Class );

__PACKAGE__->load_components( qw( Core ) );
__PACKAGE__->table( 'release_file' );
__PACKAGE__->add_columns(
    id => {
        data_type         => 'bigint',
        is_auto_increment => 1,
        is_nullable       => 0,
    },
    release_id => {
        data_type => 'bigint',
        is_nullable => 1,
    },  
    filename => {
        data_type   => 'varchar',
        size        => 1024,
        is_nullable => 0,
    },
);

__PACKAGE__->set_primary_key( qw( id ) );
__PACKAGE__->resultset_attributes( { order_by => [ 'filename' ] } );
__PACKAGE__->add_unique_constraint( [ qw( release_id filename ) ] );
__PACKAGE__->belongs_to(
   release => 'CPANHQ::Storage::Result::Release',
   'release_id'
);

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
