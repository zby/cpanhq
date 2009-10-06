package CPANHQ::Controller::Package;

use strict;
use warnings;
use base 'Catalyst::Controller';

=head1 NAME

CPANHQ::Controller::Package - Catalyst Controller for Packages

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

use Pod::Xhtml;

sub instance :Chained('/') :PathPart(package) :CaptureArgs(1)
{
    my ($self, $c, $package_name) = @_;

    my $package = $c->model('DB::Package')->find( { name => $package_name });

    if (!$package)
    {
        $c->res->code( 404 );
        $c->res->body( "Package '$package_name' not found." );
        $c->detach;
    }

    $c->stash( package => $package );
}

=head2 $self->show($c)

Showing a package.

=cut

sub show :Chained(instance) :PathPart('') :Args(0)
{
    my ($self, $c) = @_;

    my $package = $c->stash->{'package'};

    $c->stash(dist => $package->distribution, xhtml => $package->pod,);

    return;
}

=head2 index 

=cut

sub index : Private {
    my ( $self, $c ) = @_;

    my $params = $c->request->params;
    my $page = delete $params->{page} || 1;
    my $form =  My::Form->new;
    if( $form->process( $params ) ){
        my $s_params = $form->value;
        for my $key ( keys %$s_params ){
            delete $s_params->{$key} if ! defined $s_params->{$key};
        }
        $s_params->{order} //= 'me.release_date';
        $c->stash->{ packages } = $c->model( 'DB::Package' )->xsearch( 
            $s_params,
            { 
                page => $page,
                rows => 50,
            } 
        );
    }
    $c->stash( 
        form => $form, 
        template => 'package/list.tt',
        order_by_link => sub {
            my $col = shift;
            my $current = $params->{order};
            my @parts = split /\s*,\s*/, $current;
            my $done;
            for my $part (@parts){
                if( $part eq $col ){
                    $part = "$col desc";
                    $done = 1;
                }
                elsif( $part eq "$col desc"){
                    $part = $col;
                    $done = 1;
                }
            }
            if( !$done ){
                push @parts, $col;
            }
            my $order = join ', ', @parts;
            return $c->req->uri_with( { order => $order, page => 1 } );
        }
    );
}

{

    package My::Form;
    use HTML::FormHandler::Moose;
    extends 'HTML::FormHandler';
    with 'HTML::FormHandler::Render::Simple';

    has '+http_method' => ( default => 'GET' );
    has_field 'query';
    has_field 'author';
    has_field 'younger_than' => ( label => 'Newer than', type => 'Date', format => "yy-mm-dd"  );
#    has_field 'include_dev' => ( type => 'Checkbox' );
    has_field 'order' => ( 
        type => 'Text', 
        apply => [ 
        { 
            check => qr/^(|me\.(release_date|name)( desc)?(, me\.(release_date|name)( desc)?)?)\z/,
#            check => qr/^aaa$/,
            message => 'Allowed ordering only by columns: "me.release_date" and "me.name" (with optional "desc" modifier).',
        }
        ]
    );
    has_field 'submit' => ( type => 'Submit', value => 'Search' );
}

=head1 AUTHOR

Shlomi Fish L<http://www.shlomifish.org/> .

=head1 LICENSE

This module is free software, available under the MIT X11 Licence:

L<http://www.opensource.org/licenses/mit-license.php>

Copyright by Shlomi Fish, 2009.

=cut

1;
