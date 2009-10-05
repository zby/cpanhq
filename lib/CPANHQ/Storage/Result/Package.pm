package CPANHQ::Storage::Result::Package;

use strict;
use warnings;

=head1 NAME

CPANHQ::Storage::Result::Package - a class representing a CPAN package/namespace

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

__PACKAGE__->load_components( qw( InflateColumn::DateTime Core ) );
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
    abstract => {
        data_type => 'text',
        is_nullable => 1,
    },
    pod => {
        data_type => 'text',
        is_nullable => 1,
    },
    release_date => {
        data_type   => 'datetime',
        is_nullable => 0,
    },
    author_id => {
        data_type => 'bigint',
        is_nullable => 1,
    },
);

__PACKAGE__->set_primary_key( qw( id ) );
__PACKAGE__->resultset_attributes( { order_by => [ 'name' ] } );
__PACKAGE__->add_unique_constraint( [ 'name' ] );
__PACKAGE__->belongs_to(
   distribution => 'CPANHQ::Storage::Result::Distribution',
   'distribution_id'
);
__PACKAGE__->has_many(
    files => 'CPANHQ::Storage::Result::ReleaseFile',
    'package_id',
);

__PACKAGE__->belongs_to(
   package_fts => 'CPANHQ::Storage::Result::PackageFts',
   'id'
);

__PACKAGE__->belongs_to( author => 'CPANHQ::Storage::Result::Author', 'author_id' );


sub latest_release
{
    my $self = shift;

    return $self->distribution()->latest_release();
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
