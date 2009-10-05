package CPANHQ::Storage::ResultSet::Package;

use strict;
use warnings;

use base qw( DBIx::Class::ResultSet::XPredicates );

sub search_for_query {
    my ( $self, $params ) = @_;
    my $search_params = {
        -nest => \[ 'package_fts MATCH ?' => [ __DUMMY__ => $params->{query} ] ],
    };
    $self = $self->search( $search_params, { join => 'package_fts' } );
    return $self;
}

sub search_for_author {
    my ( $self, $params ) = @_;
    $self = $self->search( { 'author.cpanid' => $params->{author} }, { join => 'author' } );
    return $self;
}

sub search_for_younger_than {
    my ( $self, $params ) = @_;
    $self = $self->search( { 'me.release_date' => { '>' => $params->{younger_than} } } );
    return $self;
}

1;

__END__

=head1 NAME

CPANHQ::Storage::ResultSet::Package - x predicates

=head1 SYNOPSIS

None.

=head1 DESCRIPTION

This is L<CPANHQ>'s Package result-set.

=head1 METHODS

=head1 SEE ALSO

L<CPANHQ>, L<DBIx::Class::ResultSet>

=head1 AUTHOR

Zbigniew Lukasiak

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

