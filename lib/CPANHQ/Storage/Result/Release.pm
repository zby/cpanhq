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
