#!/usr/bin/env perl6

use v6;
use Test;

my $lib;

BEGIN { $lib=q{/Users/imel/gitdev/donalgrant/p6-equations/lib} }

use lib $lib;
use-ok 'RPN';
use RPN;

subtest "Globals in RPN" => {
  ok  '5'~~/^<digit>$/,  "5 is a digit";
  ok  '*'~~/^<op>$/,     "* is an op";
  nok '55'~~/^<digit>$/, "55 is not a (single) digit";
  nok '**'~~/^<op>$/,    "** is not a (single) op";

  ok /^<digit>$/, "digit $_ is matched" for 0..9;
  ok /^<op>$/,    "op $_ is matched" for qw< + - * / ^ @ >;
  
  nok /^<digit>$/, "op $_ doesn't match to digit" for qw< + - * / ^ @ >;
  nok /^<op>$/,    "digit $_ doesn't match to op" for 0..9;
}

my $rpn=RPN.new('76+');
isa-ok $rpn, RPN;

subtest "methods" => {
  my @rpn_methods=qw<new new_from_aos rpn display aos list Numeric Str Bag BagHash formable one-away same-value>;  
  can-ok $rpn, $_  for @rpn_methods;
}

subtest "RPN Conversions" => {
  is( $rpn.rpn, '76+', "public method rpn for RPN");
  is( $rpn.Numeric, 13, "simple addition" );

  ok( $rpn.Bag == Bag.new('76+'.comb), 'RPN converts to Bag' );
  ok( $rpn.BagHash == BagHash.new('76+'.comb), 'RPN converts to BagHash');
}

subtest "Construction" => {
  is( RPN.new("76+").Numeric, 13, "cached" );
  is( RPN.new('76*').Numeric, 42, "simple multiplication" );
  is( RPN.new('82/').Numeric, 4,  "simple division" );
  is( RPN.new('76-').Numeric, 1,  "simple subtraction" );
  is( RPN.new('38@').Numeric, 2,  "roots" );
  is( RPN.new('25^').Numeric, 32, "exponent" );
  
  is( RPN.new('98+7-6*5/2^').Numeric, 144, "chain calculations" );
  is( RPN.new('55555+-/*').Numeric,    -5, "stacked operations" );
		
  ok RPN.new('55555+-/*').list() == qw< + - / * 5 5 5 5 5 >, "RPN list";
}

subtest "Overloading" => {
  is( +$rpn, 13, "operator overloading for value" );
  cmp-ok( +$rpn, '<', 20, "operator overloading for comparisons" );
  is( ~$rpn, "76+", "operator overloading for string" );
}

subtest "AOS" => {
  is( rpn_to_aos('76+'), '7+6', "simple rpn_to_aos conversion" );
  is( rpn_to_aos('98+7-6*5/2^'), '((((9+8)-7)*6)/5)^2', "longer rpn_to_aos conversion" );
  is( rpn_to_aos('123456/////'), '1/(2/(3/(4/(5/6))))', "long stacked rpn_to_aos" );
  
  is( $rpn.aos(), '7+6', "aos version" );
}

subtest "Paren functions" => {
  is parens_for_op('@^',qw< 7 ^ 2 >), [qw< (7^2) >], "parens_for_op max precedence";
  is parens_for_op('*/',qw< 7 / 2 >), [qw< (7/2) >], "parens_for_op med precedence";
  is parens_for_op('+-',qw< 7 - 2 >), [qw< (7-2) >], "parens_for_op low precedence";
  
  is parens_for_op('@^',qw< 7 ^ 2 + 3 * 4 >), [qw< (7^2) + 3 * 4 >], "parens_for_op max precedence mixed";
  is parens_for_op('*/',qw< 7 / 2 + 3 * 4 >), [qw< (7/2) + (3*4) >], "parens_for_op med precedence mixed";
  is parens_for_op('+-',qw< 7 - 2 + 3 * 4 >), [qw< ((7-2)+3) * 4 >], "parens_for_op low precedence mixed";
  
  is find_inner_parens('7 + (6*(2+3)) + (3/4) - 2'.comb), [ 7, 11 ], "outer parens location"; 
  is find_inner_parens('7 + (6* 2+3)) + (3/4) - 2'.comb), [ 4, 11 ], "unbalanced parens not detected";
  is find_inner_parens('7 +  6* 2+3   +  3/4  - 2'.comb), [ -1, -1 ],"no parens";
  
  ok find_inner_parens('7 +  6* 2+3)  +  3/4  - 2'.comb) == [ Nil, Nil ], "unbalanced parens inside"; 
  
  is( full_parens(' ( 7 ) '),           '7',                 "full parens example -3 (fixes redundant parens)"); 
  is( full_parens(' 7 +  '),            '7+',                "full parens example -2 (ignore unbalanced expressions)"); 
  is( full_parens('+'),                 '+',                 "full parens example -1 (ignore invalid expressions)");
  is( full_parens('7'),                 '7',                 "full parens example 0");
  is( full_parens('7 + 6'),             '(7+6)',             "full parens example 1");
  is( full_parens('7 + 6 * 2'),         '(7+(6*2))',         "full parens example 2");
  is( full_parens('7 + 6 * 2 ^ 1 @ 4'), '(7+(6*((2^1)@4)))', "full parens example 3");
  is( full_parens('(7+6)'),             '(7+6)',             "full parens example 4");  
  is( full_parens('7+(6*2)'),           '(7+(6*2))',         "full parens example 5"); 
  is( full_parens('(7+6)*2'),           '((7+6)*2)',         "full parens example 6");
  is( full_parens('(7+6*2)'),           '(7+(6*2))',         "full parens example 7");
  is( full_parens('(7+3*2)+2*3'),       '((7+(3*2))+(2*3))', "full parens example 8");
  is( full_parens('(7+3)*(2+2)*3'),     '(((7+3)*(2+2))*3)', "full parens example 9");
}

subtest "Convert AOS to RPN" => {
  is( aos_to_rpn('7'),   '7',   "aos conversion to rpn for a single number" );
  is( aos_to_rpn('7+'),  Nil, "aos conversion to rpn on invalid aos string is undefined" );
  is( aos_to_rpn('7+6'), '76+', "aos converted to rpn" );
  is( aos_to_rpn('(((((9+8)-7)*6)/5)^2)'), '98+7-6*5/2^', 'convert aos to rpn on fully parethesized expression' );
  is( aos_to_rpn($rpn.aos()), "$rpn", "identity operation for AOS.RPN.AOS" );
}

subtest "RPN and AOS Validation" => {
  ok valid_aos($rpn.aos()), "aos() is valided as aos";
  
  my $aos='  (5 +4) / (3+ 2  ) ^ (1@2)  ';
  my $rpn_version='54+32+12@^/';
  
  my $rpn_str="$rpn";
  my $original_aos=$aos;
  my $original_rpn="$rpn";
  
  is( aos_to_rpn($aos), $rpn_version, "Correct handling of spaces" );
  
  ok  valid_aos($aos),     "$aos is aos";
  ok  valid_rpn(~$rpn),    "RPN $rpn is rpn";
  ok  valid_rpn($rpn_str), "$rpn_str is rpn";
  nok valid_aos(~$rpn),    "RPN $rpn is not aos";
  nok valid_aos($rpn_str), "$rpn_str is not aos";
  nok valid_rpn($aos),     "$aos is not rpn";
  
  is( $rpn_str, $original_rpn, "No change to str by valid_* functions");
  is( $aos,     $original_aos, "No change to aos by valid_* functions");

  $rpn=RPN.new_from_aos($aos); 
  is( "$rpn", $rpn_version, "construction of RPN from aos" );

  $aos=' 3 + 2 - 5 / 6 ';
  is( full_parens($aos), '((3+2)-(5/6))', "full_parens" );

  nok valid_aos('(1+(4+3)/-4)'),    "outlier case for aos validation";
  nok valid_aos('()()()1+2'),       "outlier case for aos validation:  need for paren-content check";

  # extra parens cases
  $aos='((1+3))+((2-2))';
  ok valid_aos($aos),   "aos validation:  allow extra parens" ;

  is( full_parens($aos), '((1+3)+(2-2))', "extra parens fixed by full parens" );
  is( aos_to_rpn($aos),  '13+22-+',       "extra parens in aos ok for conversion to rpn" );

  ok valid_aos('7'),                "outlier case for aos:  a single number";
}

$rpn=RPN.new('54+32+12@^-');

subtest "same-value" => {
  ok( $rpn.same-value('08-2*'),            "two equations give same value");
  ok( $rpn.same-value(RPN.new('25-6*2+')), "two RPN's yield true same-value");
}

subtest "formable" => {
  ok(  $rpn.formable( Bag.new(qw{ 5 4 3 2 2 1 + + - ^ @ }) ),             "$rpn formable by exact bag of cubes" );
  ok(  $rpn.formable( Bag.new(qw{ 5 4 3 2 2 1 + + - ^ @ 1 2 3 4 / + }) ), "$rpn formable by excess bag of cubes" );
  nok( $rpn.formable( Bag.new(qw{ 5 4 3 2 2 1 + + - ^ }) ),               "$rpn not formable by too-small bag of cubes" );

  ok(  $rpn.formable( Bag.new(qw{ 5 4 3 2 2 ^ @ }),         Bag.new(qw{ 1 + + - }) ), "$rpn formable by exact bag of cubes after using with required cubes");
  nok( $rpn.formable( Bag.new(qw{ 5 4 3 2 2 1 + + ^ @ }),   Bag.new(qw{ 1 - / }) ),   "$rpn not formable when missing required cubes");
  nok( $rpn.formable( Bag.new(qw{ 5 4 3 2 2 1 + + - ^ @ }), Bag.new(qw{ * }) ),       "$rpn not formable when missing required cube, even with all cubes covered");
}

subtest "one-away" => {	  
  ok(  $rpn.one-away( Bag.new(qw{ 5 4 3 2 1 + + - ^ @ }) ),         "$rpn is one cube away from being a solution");
  ok(  $rpn.one-away( Bag.new(qw{ 5 4 3 2 1 + + - ^ @ 6 7 * }) ),   "$rpn is one cube away from being a solution, excess cubes not relevant");
  nok( $rpn.one-away( Bag.new(qw{ 5 4 3 2 1 + - ^ @ }) ),           "$rpn is more than one-cube away from being a solution");
  nok( $rpn.one-away( Bag.new(qw{ 5 4 3 2 2 1 + + - ^ @ }) ),       "exact cubes for $rpn is not one cube away");
  nok( $rpn.one-away( Bag.new(qw{ 5 4 3 2 2 1 + + - ^ @ 6 7 }) ),   "exact cubes for $rpn is not one cube away, excess cubes not relevant");

  ok(  $rpn.one-away( Bag.new(qw{ 5 4 3 2 1 + - ^ @ }),       Bag.new(qw{ + }) ),   "$rpn is one cube away from being a solution, one cube required");
  ok(  $rpn.one-away( Bag.new(qw{ 5 4 3 2 1 + - ^ @ 6 }),     Bag.new(qw{ + }) ),   "$rpn is one cube away from being a solution, one cube required, excess not relevant");
  nok( $rpn.one-away( Bag.new(qw{ 5 4 3 2 2 1 + - ^ @ 6 7 }), Bag.new(qw{ + }) ),   "exact cubes for $rpn is not one cube away, one cube required, excess not relevant");
  nok( $rpn.one-away( Bag.new(qw{ 5 4 3 2 1 + - ^ @ }),       Bag.new(qw{ * }) ),   "$rpn is one cube away from being a solution, but missing required cube");
  nok( $rpn.one-away( Bag.new(qw{ 5 4 3 2 2 1 - ^ @ }),       Bag.new(qw{ + + }) ), "exact cubes, including required, for $rpn is not one-cube away");
}

subtest "cubes-to-go" => {
  ok( $rpn.cubes-to-go( Bag.new(qw{ 5 4 3 2 1 + - ^ @ }) )                       == Bag.new(qw{ 2 + }), "cubes-to-go for $rpn");
  ok( $rpn.cubes-to-go( Bag.new(qw{ 5 4 3 2 1 + - ^ @ }), Bag.new(qw{ 2 }) )     == Bag.new(qw{ + }),   "cubes-to-go, with required cube");
  ok( $rpn.cubes-to-go( Bag.new(qw{ 5 4 3 2 1 + - ^ @ 6 7 }) )                   == Bag.new(qw{ 2 + }), "cubes-to-go, with excess");
  ok( $rpn.cubes-to-go( Bag.new(qw{ 5 4 3 2 2 1 + + - ^ @ }) )                   == Bag.new,            "cubes-to-go empty");
  ok( $rpn.cubes-to-go( Bag.new(qw{ 5 4 3 2 2 1 + + - ^ @ }), Bag.new(qw{ 2 }) ) == Bag.new,            "cubes-to-go, with required and excess");
  nok($rpn.cubes-to-go( Bag.new(qw{ 5 4 3 2 2 1 + + - ^ @ }), Bag.new(qw{ / }) ),                       "cubes-to-go fails required");
}

subtest "req-missing" => {
  ok( $rpn.req-missing( Bag.new(qw{ 5 4 3 }) )                 == Bag.new,            "no required missing");
  ok( $rpn.req-missing( Bag.new(qw{ 5 4 3 2 2 1 + + - ^ @ }) ) == Bag.new,            "no required missing for exact match");
  ok( $rpn.req-missing( Bag.new(qw{ 6 5 * }) )                 == Bag.new(qw{ 6 * }), "missing two cubes");
}

subtest "excess" => {
  ok( $rpn.excess( Bag.new(qw{ 5 4 3 2 2 1 + + - ^ @ 6 7 }) ) == Bag.new(qw{ 6 7 }), "excess");
  ok( $rpn.excess( Bag.new(qw{ 5 4 3 2 2 1 + + - ^ @ }) )     == Bag.new,            "(no) excess");
}

subtest "bag filtering" => {
  ok( ops_bag(Bag.new(qw{ 1 2 2 3 4 5 + + / / * * * ^ @ })) == Bag.new(qw{ + + / / * * * ^ @ }), "extract Bag of ops");
  ok( num_bag(Bag.new(qw{ 1 2 2 3 4 5 + + / / * * * ^ @ })) == Bag.new(qw{ 1 2 2 3 4 5 }),       "extract Bag of digits");
}

done-testing;
