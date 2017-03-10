package Taught::GradeTool;

# $Id: GradeTool.pm,v 1.2 2001/01/24 21:18:54 dblack Exp $
# $Name: Taught-0-0-3-pre1 $
# $Author: dblack $

use strict;
use vars qw(@letters %marks %numbs @ISA @EXPORT_OK %EXPORT_TAGS);
use Exporter;

@ISA = qw(Exporter);
@EXPORT_OK = qw(@letters %marks %numbs @ISA @EXPORT_OK );
%EXPORT_TAGS = ( standard => [ @EXPORT_OK ] );

sub setonhall {
    my $proto = shift;

    @letters = qw( A B+ B C+ C D+ D F );
    %marks = map { $letters[$_], $_ + 1 } (0..$#letters);
    $marks{N} = $marks{NC} = 0;
    %numbs  = reverse %marks;

    return sub {
        my ($s, $total, $done, $zero, $report, $verbose) = @_;
    
        # Most of this has to do with how to factor in a no-credit
        # assignment.
        #
        # The basic idea is: for every $peninc points you are missing, you
        # get docked one letter (including +/-).  So if you get a zero on
        # an assignment worth 25%, you get docked 25 / $peninc letters,
        # i.e., 25 / $peninc is added to what would have otherwise been
        # your grade.  Anyway, this is all the preparatory stuff.
    
        my $incs            = @letters - 1.5;
        my $peninc      = sprintf("%.2f",(40/$incs));
        my $penalty     = sprintf("%.2f", $zero / $peninc) || 0;
        my $prepen      = $done ? sprintf("%.2f", $total / $done) : 0;
        my $final       = sprintf("%.2f", $prepen + $penalty);
        my $ordinal     = sprintf("%.0f", $final-.01);
            
        my $letter      = $numbs{$ordinal} || 'F';
        if ($verbose) {
            my $round = $prepen =~ /(\d+)\.50$/
                    ? "\nRounding down to $1\n"
                    : "";
        
            if ($done != 100) {
                print <<EOM;
                  Percentage done/not done: $done/$zero
                  Pre-penalty average: $prepen
                  Penalty: $penalty  ($zero missing points / increment of $peninc)
EOM
            }
            print "Number grade: $final\n";
            print $round if $round;
            print "Letter grade: $letter\n\n";
        }
        else {
            $report->{$s} = $letter;
        }
    }
}

sub percents {

    my $proto = shift;

#   For this one, numbers map by decades onto letters.
#
#   %marks just turns numbers into themselves (since
#   the grades are already numbers).    

    %numbs = 
                (   (map { $_, 'A' } (90..100)),
                    (map { $_, 'B' } (80..89)),
                    (map { $_, 'C' } (70..79)),
                    (map { $_, 'D' } (60..69)),
                    (map { $_, 'F' } (0..59)), );
    
    
    %marks = map { $_, $_ } (0..100);
    $marks{N} = $marks{NC} = 0;

    return sub {
        my ($s, $total, undef, undef, $report, $verbose) = @_;
        $report->{$s} = $numbs{sprintf "%.2d", $total / 100 + .5};
    }
}

1;
