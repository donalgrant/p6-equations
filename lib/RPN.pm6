use v6;

use Test;
use Globals;

class RPN {

  has $.rpn;

  method new ($rpn) { rpn_value($rpn).defined ?? self.bless(:$rpn) !! Nil }
  method new_from_aos ($aos) {
    my $rpn=aos_to_rpn($aos);
    return Nil unless $rpn.defined;
    return self.bless(:$rpn);
  }

  method display { $!rpn }
  method aos     { return rpn_to_aos($!rpn) }  
  method list    { $!rpn.comb }

  method Numeric { rpn_value($!rpn)       }
  method Str     { self.display           }
  method Bag     { self.Str.comb.Bag      }
  method BagHash { self.Str.comb.BagHash  }

  multi method same-value( RPN $r ) { return self.Numeric == $r.Numeric }
  multi method same-value( Str $r ) { return self.Numeric == rpn_value($r) }

  method formable(    Bag $per, Bag $req=Bag.new ) { (self.Bag (<=) ($per (+) $req))           and self.has($req) }
  method one-away(    Bag $per, Bag $req=Bag.new ) { (self.Bag  (-) ($per (+) $req)).total==1  and self.has($req) }
  
  method cubes-to-go( Bag $per, Bag $req=Bag.new ) { self.has($req) ?? ( (self.Bag (-) $req) (-) $per ) !! Nil }
  method req-missing( Bag $req )                   { $req (-) self.Bag }
  
  method has( Bag $req )  { self.Bag (>=) $req }
  
  method excess( Bag $all ) { $all (-) self.Bag }

  method rpn_at_op(Str $op, Int $nskip=0) { rpn_at_op($!rpn,$op,$nskip) }
}

# Exported Global Functions -- not part of the RPN class itself


my %RPN_CACHE;   # maintained for all objects
my %NUM= ^10 X=> 1;

# Regexes / Tokens go here... MOVE TO GLOBALS?

our token digit            { \d }
our token op               { '+' | '-' | '*' | '/' | '^' | '@' }
  
my token open_p           { '(' }
my token close_p          { ')' }
my token paren            { <open_p> | <close_p> }

grammar WF_AOS {
  token TOP  {
    [ <digit> [ <op> <TOP> ]* ] |
    [ <pterm> [ <op> <TOP> ]* ]
  }
  token pterm { '(' <TOP> ')' }
}

grammar WF_RPN {
  token TOP {
    :my $*OP_CNT=0;
    :my $*DGT_CNT=0;
    [ <rpn_dig> | <rpn_op> ]+ <?{ $*OP_CNT == $*DGT_CNT-1 }>
  }
  token rpn_dig  { <digit> { $*DGT_CNT++ } }
  token rpn_op   { <op>    { $*OP_CNT++  } <?{ $*OP_CNT <= $*DGT_CNT }> }
}

multi sub rpn(Int $n) is export { RPN.new($n.Str) }  # single digit construction
multi sub rpn(Str $s) is export { RPN.new($s) }
multi sub rpn(RPN $r) is export { $r }

sub filter_bag(Bag $b, &filter) { my @b=$b.kxxv; bag( @b.grep({ &filter }) ) }
  
sub ops_bag(Bag $b) is export { filter_bag($b, &op    ) }
sub num_bag(Bag $b) is export { filter_bag($b, &digit ) } 

sub rpn_value_nc2($rpn) { 
  return Nil unless $rpn.defined;
  return %RPN_CACHE{$rpn} if %RPN_CACHE{$rpn}.defined;
  return %RPN_CACHE{$rpn}= +$rpn if $rpn.chars==1;
  rpn_value_2($rpn); 
}

sub rpn_value_nc1($rpn) { 
  return Nil unless $rpn.defined;
  return %RPN_CACHE{$rpn} if %RPN_CACHE{$rpn}.defined;
  return %RPN_CACHE{$rpn}= +$rpn if $rpn.chars==1;
  rpn_value_1($rpn); 
}

sub rpn_value-new($rpn where valid_rpn($rpn)) is export { rpn_value_nc2($rpn) }
sub rpn_value($rpn where valid_rpn($rpn))     is export { rpn_value_nc1($rpn) }

sub rpn_value_2($rpn) { 
  my ($r1,$r2,$op)=decompose_rpn_nc($rpn);
  calc(rpn_value_nc2($r1),$op,rpn_value_nc2($r2));
}
  
sub rpn_value_1($rpn) { # $rpn guaranteed to be more than 1 char
  my @list=$rpn.comb;
  return 0 unless (+@list);
  my @stack;
  my $bos; 
  while (+@list and push @stack, $bos=shift @list) {
    next if %NUM{$bos}.defined;  # fastest way to do matching -- much better than ~~/\d/
    return Nil if @stack < 3;
    my $op=@stack.pop;
    my $n2=@stack.pop;
    my $n1=@stack.pop;
    my $v=calc($n1,$op,$n2);
    return %RPN_CACHE{$rpn}=Nil unless $v.defined;
    push @stack, $v;
  }
  return %RPN_CACHE{$rpn}=shift @stack;
}

# in Perl5 profiling, this was faster than using given/when or $opssubs{$op}->($n1,$n2)

sub calc ($n1,$op,$n2) is export {
  return Nil unless ($n1.defined and $n2.defined);
  return $n1+$n2                                                          if $op eq '+';
  return $n1-$n2                                                          if $op eq '-';
  return $n1*$n2                                                          if $op eq '*';
  return ( ($n2==0)                            ?? Nil !! $n1/$n2        ) if $op eq '/';
  return ( ($n1==0 and $n2 < 0) or ($n2 > 100) ?? Nil !! $n1**$n2       ) if $op eq '^';  # should be abs($n2)
  return ( ($n1==0 or ($n2 < 0 and $n1 > 0))   ?? Nil !! $n2**(1.0/$n1) ) if $op eq '@';  # should do more range checks
  quit "Unrecognized operator:  $op";
}

sub valid_rpn ($rpn) is export { $_=$rpn; s:g/\s+//; return so WF_RPN.parse($_) }
sub valid_aos ($aos) is export { $_=$aos; s:g/\s+//; return so WF_AOS.parse($_) }

sub aos_to_rpn ($aos) is export {
  return Nil unless valid_aos($aos);
  $_=$aos;
  s:g/\s+//;
  my @c=full_parens($_).comb;  # guarantees syntax for the rest of the conversion
  return @c[0] if +@c==1;      # special case of a single digit
  my (@ops,@num,@eq);
  for @c -> $c {
    if    ($c~~/ <digit>   /) { push @num,$c }
    elsif ($c~~/ <op>      /) { push @ops,$c }
    elsif ($c~~/ <open_p>  /) { }  # nop
    elsif ($c~~/ <close_p> /) { push @eq, |@num; push @eq, pop @ops; @num=() }
    else                      { quit "unrecognized character $c in aos" }
  }
  return @eq.join('');
}

# not quite sure what the best spacing and parentheses are

sub _rpn_array_to_aos (@R) {
  return @R[0] if @R.elems==1;
  my $i=2;
  while ( !(@R[$i]~~/^ <op> $/) ) { $i++; last if $i>@R.elems }  # should return error -- last token must be op!
  my $s1=(@R[$i-2]~~/ <close_p> \s* $ /) ?? '' !! '';          # for now, always no space
  my $s2=(@R[$i-1]~~/^ \s* <open_p>   /) ?? '' !! '';          # ...on both sides
  my $e=@R[$i-2]~$s1~@R[$i]~$s2~@R[$i-1]; 
  my @x=@R.elems>3 ?? "($e)" !! $e;
  @x.unshift(|@R[0..$i-3]) if $i > 2;
  @x.append(@R[$i+1..@R.end])  if $i < @R.end;
  return _rpn_array_to_aos(@x);
}

# argument to rpn_to_aos must be guaranteed to be a valid RPN.  
# can use valid_rpn to ensure this if necessary

sub rpn_to_aos ($R) is export { return _rpn_array_to_aos($R.comb) }

sub find_inner_parens (@c) is export {
  my $pstart;
  my $level=0;
  for ^@c -> $i { 
    if (@c[$i] eq '(') {
      $pstart=$i;
      $level++;
    }
    elsif (@c[$i] eq ')') {
      $level--;
      return (Nil,Nil) if $level < 0;  # unbalanced parens
      return ($pstart,$i);           # balanced inner parens found
    }
  }
  return (Nil,Nil) unless $level == 0;  # unbalanced parens
  return (-1,-1);                       # no parens
}

# argument is array of elements with no parens

sub parens_for_op ($op,@c-in) is export {
  my @c=@c-in;
  my @op=$op.comb;
  my @cops=@c.grep( / ^ @op $ / );
  for @cops {  # single element operator, highest precedence
    my $i=0; while (!(@c[$i]~~$_)) { $i++ }  # guaranteed to find one here
    my @r;
    for 0..$i-3 { push @r,@c[$_] }
    push @r,@c[$i-2] unless ($i-2 < 0     ) || (@c[$i-2] eq '(');
    push @r, '('~@c[$i-1..$i+1].join('')~')';
    push @r,@c[$i+2] unless ($i+2 > @c.end) || (@c[$i+2] eq ')');
    for $i+3..@c.end { push @r, @c[$_] } 
    @c = @r;
  }
  return @c;
}

sub parens_on_ops (@c-in) is export {
  my @c=@c-in;
  @c=parens_for_op('@^',@c);
  @c=parens_for_op('*/',@c);
  @c=parens_for_op('+-',@c);
  return @c;
}

sub process_inner_parens(@c) is export {
  while (my ($pstart,$pstop)=find_inner_parens(@c)) {
    last if $pstart < 0;
    return Nil unless ~$pstart;
    my $nc=@c.elems;
    my @before = ($pstart > 0)    ?? @c[0..$pstart-1]    !! ();
    my @after  = ($pstop < $nc-1) ?? @c[$pstop+1..$nc-1] !! ();
    if ($pstop-$pstart==2) { # detected redundant parens -- single number or paren expression 
      @c=@c[$pstart+1];
    } else {
      @c=parens_on_ops(@c[$pstart..$pstop]).join('');
    }
    @c.unshift(|@before) if @before.elems;
    @c.push(|@after) if @after.elems;
  }
  return False;
}

sub full_parens ($s-in) is export {
  my $s=$s-in;
  $s~~s:g/\s+//;
  my @c=$s.comb;
  # first (recursively) regularize all existing parenthesized expressions.
  return $s unless @c.elems>=3;
  while (process_inner_parens(@c)) {}   # returns false when no substitutions are left
  return parens_on_ops(@c).join('');
}

# start at index and work back to find valid RPN
sub rpn_at_index(Str $rpn where valid_rpn($rpn), Int $i where 0 <= $i <= $rpn.chars-1) is export {
  for 0..$i {
    my $s=$rpn.substr($i-$_,1+$_);
    return $s if valid_rpn($s);
  }
  quit "Should never fail to find valid rpn for $rpn starting at index $i";
}

# work back from $op to find first valid RPN

sub rpn_at_op(Str $rpn where valid_rpn($rpn), Str $op where $op~~/<op>/, Int $nskip=0) is export {
  my $i=$rpn.index($op);
  for ^$nskip { $i=$rpn.index($op,$i+1) }
  return $i.defined ?? rpn_at_index($rpn,$i) !! Nil;
}

# divide RPN into first RPN argument, second RPN argument, and operator

# divide RPN into first RPN argument, second RPN argument, and operator
sub decompose_rpn_nc(Str $rpn) {
  my $op=$rpn.substr(*-1);
  my $arg2=rpn_at_index($rpn,$rpn.chars-2);
  my $arg1=$rpn.substr(0,$rpn.chars-$op.chars-$arg2.chars);
  return [$arg1,$arg2,$op];
}

sub decompose_rpn(Str $rpn where (valid_rpn($rpn) and $rpn.chars > 1)) is export { decompose_rpn_nc($rpn) }

=begin pod

=head1 NAME

RPN.pm - Handle calculations for Equations Game

=head1 DESCRIPTION

Functions for the RPN Module:

   * Calculate value from RPN string
   * Cache RPN values calculated
   * valid_rpn   - return true if string is a valid rpn string
   * valid_aos   - return true if string is a valid aos string
   * aos_to_rpn  - convert an aos-formatted string to an rpn string
   * rpn_to_aos  - convert an rpn-formatted string to an aos string
   * full_parens - add full parentheses to aos expression so that 
                   no reliance on operator precedence is needed for interpretation.

=item valid_rpn

A string (with all spaces removed) is identified as a valid RPN string if it passes the following tests:

  * Final character in string is an operator
  * First two characters in string are numbers
  * Total number of operators must be exactly one less than the number of numbers
  * As the string is read from left to right, there must never be as many operators as numbers so far
  * Only operators and numbers are permitted (after all spaces have been removed)

This takes some time to implement, so this will not be used for all constructor calls, but only
when there is a question about the source of the input.  (I.e., from a human.)

=item valid_aos

A string (with all spaces removed) is identified as a valid AOS string if it passes the following tests:

  * All parentheses are balanced
  * Only operators, numbers, and parentheses are permitted
  * If the parentheses are ignored, the sequence of the expression must be (number operator)* number.  I.e.,
    it should start and finish with a number, and each pair of numbers must be separated by a single operator.
  * The above rules are true of every parenthesized sub-expression

=item aos_to_rpn

Examples:  ( (9+2) -8)^(3-1) ^ (6/2)   i.e., 3^(2^3) -->  92+8-31-62/^^
           ( (9+2) -8)^(3-1) / (6/3)   i.e., (3^2)/2 -->  92+8-31-^63// 
           ( (9+2) -8)@8/2             i.e., (3@8)/2 -->  92+8-8@2/
           ( (9+2) -8)@8@2             i.e., 3@(8@2) -->  92+8-82@@

I.e., exponentiation and radical take precedence to the right

  0.  Order of numbers is preserved
  1.  Order of operators is not necessarily preserved.  Can be seen as a placing
      ops on a stack, then popping one off the stack every time a close parens is encountered.
      This only works for a "fully-parenthesized" expression.

=item rpn_to_aos (via _rpn_array_to_pos) 

For example:  342/42++ --> (3+((4/2)+(4+2)))

The algorithm for converting an RPN string to an AOS string is:

  0.  Break the string into an array of strings, one element per character
  1.  Scan along the array until first operator is found -- capture that as the "center" of a new string:  '/'
  2.  Prior two characters must be numbers, since this is the first operator.  Add those before and
      after the operator, and surround with parens and (optional) white-space:  ' (4/2) '
  3.  Replace the three array elements with this single string.
  4.  Repeat from step 1 until only a single element remains.  This will be the AOS string.

The repeated operations 1-3 are accomplished by using the recursive _rpn_array_to_pos() function

=item full_parens

Need "full_parens" to make conversion from aos to rpn work conveniently.  This functon
ensures that an aos expression is fully-parenthesized, i.e., anytime there is an operator,
there will be a matching set of opening and closing parentheses showing where the start
and end of the operator's operands are.  For example:
  
     7 + 6              ==>  (7+6)
     7 + 6 * 2          ==>  (7+(6*2))
     7 + 6 * 2 ^ 1 @ 4  ==>  (7+(6*((2^1)@4)))

This function enforces operator precedence, from lowest to highest:

     Group 1:  + -
     Group 2:  * /
     Group 3:  ^ @

Within each group, the precedence is left-to-right.  Existing parentheses are unchanged:

     (7+6)       ==> (7+6)
     7+(6*2)     ==> (7+(6*2))
     (7+6)*2     ==> ((7+6)*2)
     (7+6*2)     ==> (7+(6*2))
     (7+3*2)+2*3 ==> (((7+3)*2)+(2*3))

The groups can be tokenized:

    token operator token

where each token can be a number or another group.  full_parens() enforces surrounding every group
with a pair of '()'s, by parsing the groups into these tokens, recursively, and adding parentheses
to groups where they do not exist, while paying attention to operator precedence.

Algorithm:

   0. Remove white-space, and split every character into an aray.
   1. Find any pre-existing (un-processed) parentheses, and scan to the first completed parethetical expression.  
      I.e., if the expression is 7+(6*(3+2)-4*(1-4)), then the first completed expression will be (3+2).
      a.  In the process, if the expression is found to have unbalanced paretheses, then return undef for the expression
      b.  If there are no parentheses, proceed to step 4.
      c.  Inner expression is now guaranteed to have either no parentheses, or (eventually),
          previously-validated parenthetical expressions.
   2. Process current expression to enforce full-parentheses while enforcing operator precedence:
      a.  Find left-most (unprocessed) high-precedence operator (^,@), and parenthesize that sub-expression.
          Repeat until there are no more unprocessed high-precedence operators in the sub-expression.
      b.  Repeat for medium precedence operators (*,/).
      c.  Repeat for low precedence operators (+,-).
   3. Return to step 1.
   4. Repeat step 2 one last time for the entire expression.

This is accomplished by continuously re-doing the array of expression elements.  Anytime an expression has
been "processed", the processed sub-expression becomes a single element in the array.  Thus, for the 
expression '7+(6*(3+2)-4*(1-4))', after step 2a, the current representation will be the array:

    7, +, (, 6, *, (, 3, +, 2, ), -, 4, *, (, 1, -, 4, ), )

After step 2c is completed for the first time:

    7, +, (, 6, *, (3+2), -, 4, *, (, 1, -, 4, ), )

After the returning to step 1, then executing through step 2c again:

    7, +, (, 6, *, (3+2), -, 4, *, (1-4), )

Another pass through step 1, we get after the first part of 2b:

    7, +, (, (6*(3+2)), -, 4, *, (1-4), )

By the time this iteration of 2b is completed, we have:

    7, +, (, (6*(3+2)), -, (4*(1-4)), )

And once step 2c is completed:

    7, +, ((6*(3+2))-(4*(1-4)))

the next iteration of step 1 finds no "unprocessed inner parentheses", and continues to step 4, i.e.,
the final execution of step 2.  After 2c, we have the final result:

    (7+((6*(3+2))-(4*(1-4))))

which is the fully parenthesized expression.

=end pod

