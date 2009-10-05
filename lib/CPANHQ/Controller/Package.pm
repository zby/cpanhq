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
        $c->stash->{ packages } = $c->model( 'DB::Package' )->xsearch( 
            $s_params,
            { 
                page => $page,
                rows => 50,
                order_by => 'me.release_date',
            } 
        );
    }
    $c->stash( form => $form );
    $c->stash( template => 'package/list.tt' );
}

{

    package My::Form;
    use HTML::FormHandler::Moose;
    extends 'HTML::FormHandler';
    with 'HTML::FormHandler::Render::Simple';

    has '+http_method' => ( default => 'GET' );
    has_field 'query';
    has_field 'author';
    has_field 'younger_than' => ( type => 'Date', format => "yy-mm-dd"  );
#    has_field 'include_dev' => ( type => 'Checkbox' );
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
