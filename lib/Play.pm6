use v6;

use Globals;
use RPN;

my @BP_Type = qw< Move Bonus Terminal >;
my @BP_Dest = qw< Forbidden Permitted Required >;

class Play {
  
  has $.type          is rw is required; # Type of move ('Move','Bonus','Terminal')

  has $.who           is rw = 'Unnamed'; # who is doing this move
  has $!from                = 'Unused'; # this is not currently an option in the game
  
  has $.cube          is rw; # cube being moved
  has $.bonus_cube    is rw; # cube being moved to Forbidden for bonus moves
  has $.dest          is rw; # where the cube is being moved
  has RPN $.rpn       is rw; # RPN in mind for solution (if there is one)

  has $.notes         is rw; #rationale for the move
  
  has Numeric %.solutions{Str}=();  # other solutions in mind (keys are rpn strings, values are numeric for RPN)

  submethod TWEAK {  # use this to ensure consistency
    die "Invalid type ($!type)" unless $!type eq any @BP_Type;
    given $!type {
      when 'Move'|'Bonus' {
	die "Non-terminal move must specify cube" unless $!cube.chars > 0;
	die "Non-terminal move must define dest" unless $!dest.chars > 0;
    	die "Non-terminal move must have valid destination ($!dest)" unless $!dest eq any @BP_Dest;
	proceed;
      }
      when 'Bonus' {
	die "Bonus move without specifying bonus cube" unless $!bonus_cube.chars > 0;
      }
      when 'Terminal' {
      }
    }
  }
  
  # may add display options later
  method display {
    my $tag="*** Player $!who";
    my $out;
    given $!type {
      when 'Move'     { $out="$tag moves $!cube to the $!dest section" }
      when 'Bonus'    { $out="$tag makes a bonus play:  $!bonus_cube to Forbidden and $!cube to the $!dest section" }
      when 'Terminal' {
	if ($!rpn.defined and $!rpn.Bag.elems > 0) {
	  $out="$tag goes out with equation {$!rpn.aos} using ";
	  $out ~= ($!cube) ?? "cube $!cube from Unused" !! "only cubes placed on the board already";
	} else {
	  $out="$tag calls the previous player's Bluff -- no solution is possible"; 
	}
      }
    }
    $out~="; {$!rpn.aos} is planned" if $!rpn.defined;
    $out~=": $!notes" if $!notes;
    return $out;
  }

}  # end of class declaration

=begin pod

=head1 NAME

Play.pm - A Move on a given Board in Equations

=head1 DESCRIPTION

The Play class defines objects returned by the Player class and used by the Game class to execute
Equations game play.  The Play object contains information about what move is being made, and
may also include information about the basis for the play, including equations that are being considered
and how the play was arrived at.

=head2 Object Data

    * Type of move (Move Play, Bonus Play, or Terminating Play)
    * For Move Play:  from (always Unused at present) and to (Forbidden, Permitted, Required)
    * For Bonus Play:  from (always Unused at present) and to (Forbidden/Permitted/Required) for non-Bonus Cube
    * Cube being moved
    * Bonus cube being moved to Forbidden
    * For Terminating Play:  Go Out, Resign, Call Bluff
    * For Go-out, the RPN being formed.  

=head2 Constructors

=head2 Accessors

=head2 Mutators


=end pod
