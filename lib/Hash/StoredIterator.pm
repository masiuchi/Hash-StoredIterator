package Hash::StoredIterator;

use 5.010000;
use strict;
use warnings;

use base 'Exporter';
use Carp qw/croak/;
use B;

our @EXPORT_OK = qw{
    eich
    eech
    hash_get_iterator
    hash_set_iterator
    hash_init_iterator
    hkeys
    hvalues
};

our $VERSION = '0.004';

require XSLoader;
XSLoader::load( 'Hash::StoredIterator', $VERSION );

sub eich(\%\$) {
    my ( $hash, $i_ref ) = @_;

    my $old_it = hash_get_iterator($hash);

    my ( $key, $val );

    my $success = eval {
        if ( !defined $$i_ref )
        {
            hash_init_iterator($hash);
        }
        else {
            hash_set_iterator( $hash, $$i_ref );
        }

        ( $key, $val ) = each(%$hash);

        $$i_ref = hash_get_iterator($hash);

        1;
    };

    hash_set_iterator( $hash, $old_it );
    die $@ unless $success;

    return unless defined $key;
    return ( $key, $val );
}

sub eech(&\%) {
    my ( $code, $hash ) = @_;

    my $old_it = hash_get_iterator($hash);
    hash_init_iterator($hash);

    my $success = eval {
        my $iter;

        while ( my ( $k, $v ) = eich( %$hash, $iter ) ) {
            local $_ = $k;
            # Can't use caller(), subref might be from a different package than
            # eech is called from.
            my $callback_package = B::svref_2object($code)->GV->STASH->NAME;
            no strict 'refs';
            local ${"$callback_package\::a"} = $k;
            local ${"$callback_package\::b"} = $v;
            $code->( $k, $v );
        }

        1;
    };

    hash_set_iterator( $hash, $old_it );
    die $@ unless $success;
    return;
}

sub hkeys(\%) {
    my ($hash) = @_;
    croak "ARGH!" unless $hash;

    my $old_it = hash_get_iterator($hash);
    hash_init_iterator($hash);

    my @out = keys %$hash;

    hash_set_iterator( $hash, $old_it );

    return @out;
}

sub hvalues(\%) {
    my ($hash) = @_;

    my $old_it = hash_get_iterator($hash);
    hash_init_iterator($hash);

    my @out = values %$hash;

    hash_set_iterator( $hash, $old_it );

    return @out;
}

1;

__END__


=head1 NAME

Hash::StoredIterator - Functions for accessing a hashes internal iterator.

=head1 DESCRIPTION

In perl all hashes have an internal iterator. This iterator is used by the
C<each()> function, as well as by C<keys()> and C<values()>. Because these all
share use of the same iterator, they tend to interact badly with eachother when
nested.

Hash::StoredIterator gives you access to get, set, and init the iterator inside
a hash. This allows you to store the current iterator, use
each/keys/values/etc, and then restore the iterator, this helps you to ensure
you do not interact badly with other users of the iterator.

Along with low-level get/set/init functions, there are also 2 variations of
C<each()> which let you act upon each key/value pair in a safer way than
vanilla C<each()>

This module can also export new implementations of C<keys()> and C<values()>
which stash and restore the iterator so that they are safe to use within
C<each()>.

=head1 SYNOPSIS

    use Hash::StoredIterator qw{
        eich
        eech
        hkeys
        hvalues
        hash_get_iterator
        hash_set_iterator
        hash_init_iterator
    };

    my %hash = map { $_ => uc( $_ )} 'a' .. 'z';

    my @keys = hkeys %hash;
    my @values = hvalues %hash;

Each section below is functionally identical.

    my $iterator;
    while( my ( $k, $v ) = eich( %hash, $iterator )) {
        print "$k: $value\n";
    }

    eech { print "$a: $b\n" } %hash;

    eech { print "$_: $b\n" } %hash;

    eech {
        my ( $key, $val ) = @_;
        print "$key: $val\n";
    } %hash;

It is safe to nest calls to C<eich()>, C<eech()>, C<hkeys()>, and C<hvalues()>

    eech {
        my ( $key, $val ) = @_;
        print "$key: $val\n";
        my @keys = hkeys( %hash );
    } %hash;

C<eech()> and C<eich()> will also properly handle calls to C<CORE::each>,
C<CORE::keys>, and C<Core::values> nested within them.

    eech {
        my ( $key, $val ) = @_;
        print "$key: $val\n";

        # No infinite loop!
        my @keys = keys %hash;
    } %hash;

Low Level:

    hash_init_iterator( \%hash );
    my $iter = hash_get_iterator( \%hash );
    # NOTE: Never manually specify an $iter value, ALWAYS use a value from
    # hash_get_iterator.
    hash_set_iterator( \%hash, $iter );


=head1 EXPORTS

=over 4

=item my ( $key, $val ) = eich( %hash, $iterator )

This is just like C<each()>, except that you need to give it a scalar in which
the iterator will be stored. If the $iterator value is undefined, the iterator
will be initialized, so on the first call it should be undef.

B<Never set the value of $iterator directly!> The behavior of doing so is
undefined, it might work, it might not, it might do bad things.

B<Note:> See caveats.

=item eech( \&callback, %hash )

=item eech { ... } %hash

Iterate each key/pair calling C<$callback->( $key, $value )> for each set. In
addition C<$a> and C<$_> are set to the key, and C<$b> is set to the value.
This is done primarily for convenience of matching against the key, and short
callbacks that will be cluttered by parsing C<@_> noise.


B<Note:> See caveats.

=item my @keys = hkeys( %hash )

Same as the builtin C<keys()>, except it stores and restores the iterator.

B<Note:> Overriding the builtin keys(), even locally, causes stange
interactions with other builtins. When trying to export hkeys as keys, a call
to C<sort keys %hash> would cause undef to be passed into keys() as the first
and only argument.

=item my @values = hvalues( %hash )

Same as the builtin C<values()>, except it stores and restores the iterator.

B<Note:> Overriding the builtin values(), even locally, causes stange
interactions with other builtins. When trying to export hvalues as values, a
call to C<sort values %hash> would cause undef to be passed into values() as
the first and only argument.

=item my $i = hash_get_iterator( \%hash )

Get the current iterator value.

=item hash_set_iterator( \%hash, $i )

Set the iterator value.

B<Note:> Only ever set this to the value retrieved by C<hash_get_iterator()>,
setting the iterator in any other way is untested, and may result in undefined
behavior.

=item hash_init_iterator( \%hash )

Initialize or reset the hash iterator.

=back

=head1 CAVEATS

=over 4

=item Modification of hash during iteration

Just like with the builtin C<each()> modifying the hash between calls to each
is not recommended and can result in undefined behavior. The builtin C<each()>
does allow for deleting the iterations key, however that is B<NOT> supported by
this library.

=item sort() edge case

For some reason C<[sort hkeys %hash]> and C<[sort hkeys(%hash)]> both result in
a list that has all the keys and values (and strangly not in sorted order).
However C<[sort(hkeys(%hash))]> works fine.

=back

=head1 AUTHORS

Chad Granum L<exodist7@gmail.com>

=head1 COPYRIGHT

Copyright (C) 2013 Chad Granum

Hash-StoredIterator is free software; Standard perl licence.

Hash-StoredIterator is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the license for more details.

