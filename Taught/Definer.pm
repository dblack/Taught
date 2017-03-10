package Taught::Definer;

# Taught::Definer -- tool for defining and manipulating slapdash, ad hoc,
# text-only, one-record-per-line databases.

# Taught::Definer was written by David Alan Black,
# Department of Communication, Seton Hall University.

# Taught::Definer is covered by the Perl Artistic License, q.v.

# Version 0.0.3, September 2000.

# $Id: Definer.pm,v 1.2 2001/01/24 21:18:54 dblack Exp $
# $Name: Taught-0-0-3-pre1 $
# $Author: dblack $

use strict;
use vars qw($VERSION);

$VERSION = '0.0.3';

sub TIEHASH {
    my ($class, $params) = @_;
    my $self = bless {}, $class;

#   Defaults.
#   These are the default defaults.
#   A subclass using _new can pass its own $defaults to _new.
    my $defaults = {
        CCHR                => '#',     # comment character
        HDR             => '',      # file header
        OFT             =>  '%s',       # output format string
        RO                  =>  0,          # read-only
        SSUB                =>              # sort subroutine
            '$a->[0] cmp $b->[0]',
    };

    $self->_new($params, $defaults);
}

sub _new {
    my ($self, $params, $defaults) = @_;

#   Main hash for record-keeping.
    $self->{RECS} = {};

#   Put passed parameters into $self.
#   Required parameters: file name, regex, fields.
    for ( qw(FILE SRE FLDS) ) {
        $self->{$_} = $params->{$_} || $defaults->{$_}
            or die "Missing value for $_; can't continue.\n"
    }

#   Parameters with acceptable defaults
    for (qw( CCHR HDR OFT RO SSUB )) {
        $self->{$_} =
            do {
                defined $params->{$_}
                    ? $params->{$_}
                    : $defaults->{$_}
            }
    }

#   Flag to indicate something has changed.
    $self->{CHNG} = 0;

#   Storage for malformed records.
    $self->{BADL} = [];

#   Storage for comments we find in original file.
    $self->{CMNT} = {};

#   Storage for previously found stuff after "END"
    $self->{TRAIL} = [];

#   Magically interpolate real sort subroutine
#   syntax into sort subroutine string.
    $self->_expand_ssub;

    $self->{RO} = $self->{RO} ||! $self->{OFT};
    #warn "Operating in read-only mode.\n"
#       if $self->{RO};

    if (-e $self->{FILE}) {
        $self->_readfile or die $!
    }
    elsif ($self->{RO}) {
        warn "Read-only mode, but can't find $self->{FILE}\n";
    }

    return $self;
}

sub STORE {
    my ($self, $key, $r) = @_;

#   $r is either an array ref, a hash ref, or
#   a non-ref.  In any case, @fields should receive
#   a list of all fields, in the same order as FLDS.

    my $flds = $self->{FLDS};
    my @fields = 
        do {
            if (ref $r) {
                ref $r eq 'ARRAY'
                    ? ($key, @$r)
                    : ref $r eq 'HASH'
                        ? do {
                                $r->{$flds->[0]} = $key;
                                map { $r->{$_} }  @$flds;
                            }
                        : undef
            }
            else {
                shift;
                @_;
            }
        } or return;

    $self->{CHNG}++;
    $self->_addrec($self->_normalize(\@fields));
}

sub FETCH {
    my ($self, $key) = @_;
    return $self->{RECS}->{$key};
}

sub EXISTS {
    my ($self, $key)  = @_;
    return exists $self->{RECS}->{$key};
}

sub FIRSTKEY {
    my $self = shift;
    my $r = keys %{$self->{RECS}};      # reset iterator
    $self->NEXTKEY;
}

sub NEXTKEY {
    my $self = shift;
    return each %{$self->{RECS}};
}

sub DELETE {
    my ($self, $key) = @_;
    delete $self->{RECS}->{$key};
}

# This is a quasi stub.  It should probably deal
# with other keys of $self, but not delete all
# of them.
sub CLEAR {
    my $self = shift;
    $self->{RECS} = {};
}

sub DESTROY {
    my $self = shift;
    eval { $self->_writefile };
    print $@ if $@;
}

sub touch {
    my $self = shift;
    my $chng = $self->{CHNG};
    $self->{CHNG} = 1;
    $self->_writefile;
    $self->{CHNG} = $chng;
    return $self;
}

#
# Private methods.
#

sub _writefile {
    my $self = shift;
    return if $self->{RO} ||! $self->{CHNG};

    local $\ = "\n";
    my $cchr = $self->{CCHR};

    open(OUT, "> $self->{FILE}") or die $!;
    my $oldfh = select OUT;

#   Header.
    if ($self->{HDR}) {
        my $hdr = $self->{HDR};     #   Preserve original for subsequent writes.
        $hdr =~ s/(^|\n)/$1$cchr /g;
        print $hdr;
    }

#   Field names header.
    my $line = $cchr . '_' x 50;
    my $fnh = sprintf "$cchr $self->{OFT}", @{$self->{FLDS}};
    $fnh =~ s/  //;     # Peel two spaces out, for alignment
    print for
        $line,
        $fnh,
        $line;

#   Records and interspersed comments.
    for my $r ($self->_sortrecs) {
        if (exists $self->{CMNT}{$r}) {
            print for @{$self->{CMNT}{$r}};
            delete $self->{CMNT}{$r};
        }
        print
            $self->_normalize(
                [   map { $self->{RECS}->{$r}->{$_} }
                    @{$self->{FLDS}}    ]);
    }

#   End marker.
    print "END";

#   Malformed lines.
    if (@{$self->{BADL}}) {
        print
            "$cchr $_"
                for ("Malformed lines found: ",
                @{$self->{BADL}});
    }

    if (@{$self->{TRAIL}}) {
        print "$cchr Post-END material from original file:";
        for my $t (@{$self->{TRAIL}}) {
            $t =~ s/^[$cchr\s]+/$cchr /;
            print "$t";
        }
    }

#   Stray comments
    if (keys %{$self->{CMNT}}) {
        print "$cchr Stray comments from original file:";
        for my $c (keys %{$self->{CMNT}}) {
            print @{$self->{CMNT}{$c}};
        }
    }
    select $oldfh;
    close OUT;
}

sub _readfile {
    my $self = shift;
    my $cchr = $self->{CCHR};

    my @comments = ();

    my $inbody = 0;

    open(IN, "< $self->{FILE}") or return;
    while (defined (my $line = <IN>)) {
        chomp $line;
        $inbody = 1 if $line =~ /^\s*[^$cchr]/;
        if ($line =~ /^end$/i) {
            if (@comments) {
                $self->{CMNT}{stray} = [ @comments ];
            }
            while (defined (my $inner = <IN>)) {
                chomp $inner;
                push (@{$self->{TRAIL}}, $inner)
                    unless $inner =~ /post-end/i
            }
            last;
        }
        elsif ($line =~ /^\s*$cchr/) {
            next unless $inbody;
            push @comments, $line;
        }
        else {
            if (@comments) {
                my ($key) = $line =~ /$self->{SRE}/x;
                $self->{CMNT}{$key} = [ @comments ];
                @comments = ();
            }
            $self->_addrec($line);
        }
    }
    close IN;
}

sub _addrec {
    my ($self, $line) = @_;
    return unless $line =~ /\S/;
    chomp $line;

    if (my (@fields) = $line =~ /$self->{SRE}/gx) {

    #   First field serves as RECS hash key, and also
    #   reappears as the first value in the new hash.

        $self->{RECS}->{$fields[0]} =
            {   map {
                    $self->{FLDS}->[$_],
                    $fields[$_]
                } (0 .. $#fields)
            }
    }
    else {
        warn "Warning: Malformed line:\n\"$line\"\n";
        push @{$self->{BADL}}, $line;
    }
}

sub _normalize {
    my ($self, $fields) = @_;
    return
        sprintf "$self->{OFT}", @$fields;
}

sub _sortrecs {
    my $self = shift;

    my $sub = eval "sub { $self->{SSUB} }";
    return
        map { $_->[0] }
        sort $sub
        map { [ $_, $self->{RECS}->{$_} ] }
        keys %{$self->{RECS}}
};

sub _expand_ssub {
    my $self = shift;
    for my $f (@{$self->{FLDS}}) {
        $self->{SSUB} =~ s/($f)(.*?)($f)/
                                    \$a->[1]->{$f}
                                        $2
                                    \$b->[1]->{$f}
                                /gsx;
    }
}

__END__

=head1 NAME

Taught::Definer.pm - tool for defining ad hoc-ish, plain-text database formats

=head1 SYNOPSIS

 use Taught::Definer;


 # Define behavior of new plain-text database format:

 my $specs = {
      FILE => 'datafile',             # File for read/write
      CCHR => ';',                    # Comment character
      OFT  => '%-25s%-4s%-4s%-4s',    # Output format string
      ....                            # (see DESCRIPTION)
 };

 tie %grades, "Taught::Definer", $specs;


 # Add record using hash reference:

 $grades{"Student, John Q."} =
     {
       'Exam 1'     => 'B',
       'Exam 2',    => 'C',
       'Term Paper' => 'C+'
     };


 # Or add same record using array reference:

 $grades{"Student, John Q."} = [ qw( B C C+ ) ];


 # Result: a record (one line) in a text file:

 Student, John Q.         B   C   C+


 # Records can be deleted, iterated over, etc., as per any
 # full implementation of a hash tie.  File can be updated
 # with a Taught::Definer program, or in a text editor.

=head1 DESCRIPTION

Taught::Definer is a tool for defining and manipulating simple plain-text,
single-file database formats.  To define a Taught::Definer database format, you
specify field names, an output string to convert records to lines in a file, a
regular expression against which lines are matched to re-create record fields,
and other particulars.  Then you use a tied hash to manipulate your data.
Taught::Definer takes care of creating the file, which you can then process
further with your program or edit by hand.

Taught::Definer exists for the benefit of people who, like me, store lots of
data in text files because they want to be able both to edit them manually and
to process them batchwise when needed.  I do this with things like grade lists,
class rosters, and course description files (lists of a course's requirements
and percentage values).  I edit these files by hand a lot, but I also write a
lot of scripts which have to read and merge the files in one way or another.
Since each such file (or file type) has a different format for its lines, I end
up (re)writing lots of ad hoc regular expressions, repetitive tests for comment
lines, and so forth.

Taught::Definer does not do away entirely with the ad hocness of this kind of
approach to data storage.  Principally, rather, it neatens things up and
simplifies maintenance.  If you are repelled by the idea of semi-on-the-fly
database formats, then Taught::Definer will not appeal to you.  If, on the
other hand, you like the idea of plain-text storage which can also easily be
batched processed, but are sick of typing "C<next if /^\s*#/;>", then
Taught::Definer may help you a lot.

=head2 Defining a Taught::Definer database (overview)

(See also EXAMPLE, which is in semi-tutorial form.)

Taught::Definer allows you to specify how you want your text database to look
and behave.  When you tie the hash, you pass along a hash reference with values
for certain required keys, and perhaps for some optional ones.  (See below,
"Database format specifiers".) Thereafter, you add records like this:

    $hash{"David"} = { Number => 123, String => "hi" };

Note that the key you send (David) automatically gets paired with the first
field (Name), which you therefore do not have to specify.

If you respect the order of the fields (as they appeared in FLDS, above), you
can even skip the field names and use an array reference:

     $hash{David} = [ qw( 123 hi ) ];

or even a list:

    $hash{David} = qw( 123 hi );

After any of the above assignments, you can do:

    print $hash{David}->{Name};
    delete $hash{David};

and so forth.  When your program is finished, Taught::Definer will write
your data into a text file, using the output string you have
specified to format the records.  

=head2 Database format specifiers

When you tie your Taught::Definer hash, you need to pass a hash reference:

    tie %hash, 'Taught::Definer', $hashref;

The hash behind I<$hashref> has to have values defined for certain keys, and
may have values defined for some other ones.  Here -- starting with the
required ones -- are the keys available to you for specifying a Taught::Definer
database

=over 4

=item FILE

Full path to the file you want Taught::Definer to read and write.

Required.

=item FLDS

The field names you want to use, e.g. "Name", "Age", "Height", etc.
The first field name in the list is used as a hash key to get at all the other
fields.  That means that it must be unique.  If you are listing people and two
of them have the same name, you'll have to find some way to differentiate them.

Required.  The value must be an array reference (C<[ qw(Name Age ...) ]>).

=item OFT

The output format string for your records.  For example, if you have
fields for name and age, your string might be C<'%25s%5d'>.  (This
string gets sent straight to C<(s)printf>.)  If you don't supply a
string here, your program will operate in read-only mode.  (You can
achieve that with the RO flag, too.)

Required.

=item SRE

A regular expression used for parsing input from an existing file.
When your Taught::Definer program is parsing the data file, it
will test each line against this pattern.  Thus the regex should have pairs of
parentheses exactly corresponding to the fields you want to capture.  Each
record will be stored as a hash, the keys being your field names and the values
being I<$1>, I<$2>, ... from this pattern-matching test.  

Required.

=item CCHR

Comment character.  Lines in your Taught::Definer database file(s)
starting with this character will be treated as comments.
(The pattern for matching commented-out lines
is C</\s*$c/>, where C<$c> is the comment character.)  Note that
comments have to be on their own lines; they cannot follow data
on a data line.

Optional; default is C<'#'>.

=item HDR

File header.  This header will appear, commented out with your comment
character, at the top of your data file.  The header gets clobbered and
replaced each time Taught::Definer handles your file, so don't spend
too much time tweaking the header by hand in a text editor.

Optional (default: none)

=item SSUB

The sort subroutine for output.  Except don't pass a sub reference;
pass a string.  In fact, you can do something like this:

    SSUB => 'Age <=> Age'

(assuming you have an Age field), and Taught::Definer will output your records
sorted that way.

Optional; default is an alphanumeric comparison of the first field.

=item RO

If RO exists, your program will operate in read-only mode.  This also happens
if you don't supply an output format string (OFT).

=back

=head2 Taught::Definer's file format

Taught::Definer puts your data in a file with the following structure:

  HEAD:
    header
    field names (surrounded by nice "------" lines :-)
  BODY:
    records (with comments interspersed)
    END marker
    Post-END material:
      Stray comments (not associated with an existing record)
      Malformed records that can't be otherwise output
      Post-END material from the previous version of the file

When reading records from an existing file, Taught::Definer considers itself
to have reached the body when it encounters the first non-comment
line.  The head (header and field-names line) gets clobbered each time
Taught::Definer handles your file.  So if you want to add anything that will
persist in the file, put it in the body.

The Post-END material includes
anything anomalous that Taught::Definer
found in the file, or in your session data.  This includes
all stray comments (see L<"Comment lines">, below) and all malformed
records (see L<"Invalid or malformed records">, below).

Thus, after "END", you might see something like this in your file
after a couple of runs of your program:

  # Stray comments from original file:
  # this student is great
  # this one isn't
  # Post-END material from original file:
  # Stray comments from original file:
  # this comment was in a yet earlier version of the file
  # Malformed lines found:
  # Smith, J0h4       B   A   B+

This should help you deal with any weirdnesses in the data; you can
manually fix broken lines and put them back in the mix.

While some effort is made not to increase the size of the Post-END
section too rapidly, if you're getting anything there you probably
should go into your file with a text editor and fix it or get rid
of it.  Otherwise it may get included again as "from original
file" :-)

=head2 Comment lines

When it updates a file, Taught::Definer preserves comments which
occur before a given record.  In other words, if your file has this:

  # This guy is not
  # living up to his potential
  Student, John Q.      C   D+  C+

then those two comment lines will be preserved, just prior to the
JQS line, in the updated file (even if JQS's grades change -- it's
keyed to the first field).  You should therefore put comments
before the line they apply to.

If you delete JQS during an editing session or a run of your
Taught::Definer program, the comments which were attached to him will
be put at the bottom of your file, just in case you wanted to
see them again.

=head2 Invalid or malformed records

Taught::Definer will issue a warning when it encounters a malformed record.
(The test for malformation is a match against the pattern you have
specified with the SRE key.)  Taught::Definer will notice malformed records
in files and also on the fly, e.g., if it's receiving keyboard input
and constructing record lines from that input.

All malformed lines get placed at the end of your data file, so that
you can deal with them at your leisure.  

=head2 Inheriting from Taught::Definer

If you want to write several scripts that all deal with
the same kind of database, you might want to create a new
module by inheriting from Taught::Definer and setting the defaults
to be what you want.  I've done something similar to this
for handling class rosters, for example, so that I don't have
to define all of Taught::Definer's parameters every time I write a
script which has to parse a class roster.

=head1 EXAMPLE

Here's an extended example, with some repetition of
explanation (because I wrote this separately and
transplanted it here).  You should read it and also
run it.  (Make sure you don't have a file called
agents.dat :-)

  #/usr/bin/perl -w
# $
# $Name: Taught-0-0-3-pre1 $
# $Author: dblack $

  
  use strict;
  use Taught::Definer;
  
  # Records can be created with either a hash reference
  # or an array reference.
  #
  # Hash first:
  #
  # The records are keyed on whatever the first field
  # (in FLDS) is.  In this case, it's Name.
   
  my %agents;
  tie %agents, "Taught::Definer", {
    FILE    =>  "agents.dat",       # File name
    CCHR    =>  ';',                # Comment character
                                    # Regex for parsing records:
    SRE     =>  '(^[\ \w.,\'-]+\b)  # Name
                \s+
                (\d+)               # Number
                \s+
                ([\w\ ]+\b)         # Rank
                \s*$',
    OFT     =>  '%-25s%-12s%-20s',  # Format string for output
    FLDS    =>  [ qw(   Name
                        Number
                        Rank
                ) ],                      # Record fields
    HDR     =>  "Taught::Definer test file",     # File header
    SSUB    =>  "Number <=> Number",      # How to sort on output
  };
  

  # Create some records, using the hash reference approach.

  $agents{"Steed, John"} =
       {
           Number => 2,
           Rank => 'Top professional'
       };
  
  $agents{"Peel, Emma"} =
       {
           Number => 1,
           Rank => 'Talented amateur'
       };
  

  # Play around with those records.

  my $agent = "Steed, John";
  print "Steed is accounted for....\n" if exists $agents{$agent};
  print "Getting rid of Steed\n";
  delete $agents{$agent};
  print "Steed is gone.\n" unless exists $agents{$agent};
  
  
  # Create a record with the array reference approach.
  # Make sure the data are in the same order as the "FLDS"
  # list.  The hash key ("King, Tara") takes care of "Name".
  # The rest will be saved under the remaining field names,
  # in order.
   
  $agents{"King, Tara"} = [ (0, "yes") ];
  
  print "Agent Tara King.  Rank: ",
        $agents{"King, Tara"}->{Rank},
        "\n";

  print "\nNow let's try to save an invalid record.\n\n";

  $agents{'Nobody, !#)%'} = [ (-1, "whatever") ];

  print "
  You should have just gotten a warning message, and you
  should find that malformed record at the end of your
  output file, awaiting repair (or consignment to oblivion)
  by you.

  Try editing the file agents.dat manually -- maybe put in
  a comment, or a malformed line  -- and then run this script again.
  Then look at the file again, and see how everything got treated..
  ";
  __END__


=head1 HISTORY

Already babbled about under DESCRIPTION.

=head1 AUTHOR

David Alan Black (blackdav@shu.edu), Department of
Communication, Seton Hall University.

=head1 BUGS AND LIMITATIONS

Taught::Definer takes an optimistic view of things.  It assumes that no one
else is performing database operations on your class roster or private ASCII
address file at the same time that you are.   And a few other unworldly
things like that.  I would be grateful to hear of any bugs which you find.

=head1 COPYRIGHT

Taught::Definer is distributed under the Perl Artistic License, q.v.

=cut
