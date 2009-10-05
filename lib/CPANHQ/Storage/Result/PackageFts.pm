package CPANHQ::Storage::Result::PackageFts;

use strict;
use warnings;

=head1 NAME

CPANHQ::Storage::PackageFts - fts3 index for Package

=head1 SYNOPSIS
      

=head1 DESCRIPTION


=head1 METHODS

=cut

use base qw( DBIx::Class );

__PACKAGE__->load_components( qw( Core ) );
__PACKAGE__->table( 'package_fts' );
__PACKAGE__->add_columns(
    id => {
        data_type         => 'bigint',
        is_auto_increment => 1,
        is_nullable       => 0,
    },
    package_name => {
        data_type   => 'varchar',
        size        => 1024,
        is_nullable => 0,
    },
    abstract => {
        data_type => 'text',
        is_nullable => 1,
    },
);

__PACKAGE__->set_primary_key( qw( id ) );

=head1 SEE ALSO

L<CPANHQ::Storage>, L<CPANHQ>, L<DBIx::Class>

=head1 AUTHOR

Zbigniew Lukasiak L<http://zbigniew.lukasiak.name/> .

=head1 LICENSE

This module is free software, available under the MIT X11 Licence:

L<http://www.opensource.org/licenses/mit-license.php>

Copyright by Zbigniew Lukasiak, 2009.

=cut

1;
