#!/usr/bin/env perl
my $copyright =<<'COPYRIGHT';
Copyright (c) 2018, Yasuhiko Watanabe
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:
* Redistributions of source code must retain the above copyright notice, 
  this list of conditions and the following disclaimer.
* Redistributions in binary form must reproduce the above copyright notice, 
  this list of conditions and the following disclaimer in the documentation 
  and/or other materials provided with the distribution.
* Neither the name of the <organization> nor the names of its contributors 
  may be used to endorse or promote products derived from this software 
  without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL <COPYRIGHT HOLDER> BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
COPYRIGHT


use strict;

use Getopt::Long qw(:config posix_default no_ignore_case gnu_compat );

my $JOT = '/usr/bin/jot';
my $MAX_WORDS = 20; 
my $MAX_CHARS = 30;


my @alpha = ('a','b','c','d','e','f','g','h','i','j','k','l','m','n',
	     'o','p','q','r','s','t','u','v','w','x','y','z');
my @numeric = ('0','1','2','3','4','5','6','7','8','9');

my @alphanumeric;
push(@alphanumeric, @numeric);
push(@alphanumeric, @alpha);

my @Alphanumeric;
push(@Alphanumeric, @alphanumeric);
push(@Alphanumeric, map {uc} @alpha);

# command line options
# options are parsed by GetOptions();
my $opt_practice = 0;
my $opt_style = "word";
my $opt_entropy10 = 23;
my $opt_dictionary = '/usr/share/dict/words';
my $debug = 0;

my $BNC_ALL = "bnc_all_rank.txt";


if(defined($ENV{'RNDPASS_DICTIONARY'})){
    $opt_dictionary = $ENV{RNDPASS_DICTIONARY};
}

my $oldsignal = $SIG{__WARN__};
$SIG{__WARN__} = sub {}; # drop it. GetOption raise warn if unknown option is provided.
my $opt = GetOptions(
    "help" => sub {usage()},
    "dictionary=s" => \$opt_dictionary,        
    "entropy=i" => \$opt_entropy10,
    "practice" => \$opt_practice,
    "prepare=s" => \&prepare,
    "style=s" => \$opt_style,
    "debug" => \$debug
    );
$SIG{__WARN__} = $oldsignal; # recover handler.

if(!$opt){

    &usage("Unknown option");
}

if($debug){
    print <<"EOF";
style:$opt_style
practice:$opt_practice
entropy:$opt_entropy10
dictionary:$opt_dictionary
EOF
}

my @dict = &read_dict($opt_dictionary);


my @choice;
my $jot_max;
if($opt_style eq "word"){
    @choice = @dict;
    $jot_max = $MAX_WORDS;
}elsif($opt_style eq "Word"){
    @choice = @dict;
    $jot_max = $MAX_WORDS;
}elsif($opt_style eq "alphanum"){
    @choice = @alphanumeric;
    $jot_max = $MAX_CHARS;    
}elsif($opt_style eq "Alphanum"){
    @choice = @Alphanumeric;
    $jot_max = $MAX_CHARS;    
}else{
    &usage("option $opt_style");
}

if($#choice <= 0){
    &usage("dictionary incorrect");
}

my @random_sequence = &generate_sequence($jot_max, @choice);
my ($length, $ent10) = &check_entropy($#choice + 1, $jot_max, $opt_entropy10);
if($length <= 0){
    &usage("too little entropy");
}
splice(@random_sequence, $length); # splice is destructive operator



my @conv;
my $separator = "";
if($opt_style eq "word"){
    @conv = map {&toSpace($_)} (map {lc($_)} @random_sequence);
    $separator = ' ';
}elsif($opt_style eq "Word"){
    @conv = map {&toSpace($_)} (map {ucfirst($_)} @random_sequence);
}elsif($opt_style eq "alphanum"){
    @conv = @random_sequence;
}elsif($opt_style eq "Alphanum"){
    @conv = @random_sequence;
}else{
    &usage("Unknown style $opt_style");
}

my $pass = join($separator, @conv);

printf "complexity:%.2f\nlength:%d\n", $ent10, length($pass);
print "\n$pass\n\n";


if($opt_practice == 1){
    &practice($pass);
}


# return number of words neccsary to full fill $entropy10 criteria.
sub check_entropy{
    my($choice, $max_choice, $entropy10) = @_;
    my $c = 1;
    for(my $i = 0; $i < $max_choice; $i++){
	$c = $c * $choice;
	my $e10 = log($c)/log(10.0) ;
	if($e10 > $entropy10){
	    return ($i + 1, $e10);
	}
    }
    return (0, 0);
}

sub generate_sequence{
    my($max_choices, @list) = @_;
    my @index = &jot($max_choices, 0, $#list);
    my @res;

    for(my $i = 0; $i <= $#index; $i++){
	my $ix = $index[$i];
	$res[$i] = $list[$ix];
    }
    return @res;
}

sub read_dict{
    my($DICT) = @_;
    open(my $F, "$DICT") or die "$!:$DICT";
    my @DICT;

    while(my $word = <$F>){
	$word =~ s/^\t//;
	$word =~ s/(\t.+)//;	
	$word =~ s/[\r\n]//g;
	push @DICT, $word;
    }
    return @DICT;
}


# Get random sequence.
# Random source is jot command.
sub jot{
    my($words, $start, $num) = @_;

    my $res = `$JOT -s ' ' -r $words $start $num `;
    if($?){
	die "$!";
    }
    return (split / /, $res);
}

sub toSpace{
    my($word) = @_;
    $word =~ tr/\_/ /;
    return $word;
}

sub prompt{
    my($pass, $opt) = @_;
    if($opt eq 'SHOW'){
	print "$pass>";
    }else{
	print ">";
    }
}

sub getLine{
    my $line = <>;
    chomp$ line;
    return $line;
}

sub practice{
    my($pass) = @_;
    my $level = 'SHOW';
    do{
	&prompt($pass, $level);
	my $response = &getLine();
	if($pass eq $response){
	    $level = 'GOOD';
	}else{
	    $level = 'SHOW';
	}
    }while(1)
}




sub usage{
    my($reason) = @_;
    my($name_stripped) = $copyright;
    my $copyright_name_stripped = $copyright;
    $copyright_name_stripped =~ s/(Copyright.+\n)//g;

    my $reason_str;
    if($reason ne ""){
	$reason_str = "error:$reason\n";
    }
    
    print STDERR <<"EOF";
usage: $0 [--help] [--style (word|Word|alphanum|Alphanum)] [--practice] [--entropy digits] [--prepare (mac|linux)]
$reason_str
This software does not gurantee the secureness of generated password in any sense.
The most important issue is random source of jot command, which we use for this command's random source,
because jot command of some system lacks good randomness.
EOF
    exit 1;
}

# If you do not have /usr/share/dict/words, you may use list of English words from
# British National Corpus https://corpus.byu.edu/bnc/
# Below is a frequency list bsed on the corpus, but if you use it, some words can appear
# multiple file and cause biased results.
sub prepare{
    my ($opt_name, $opt_value) = @_;
    my $URL = qw(http://ucrel.lancs.ac.uk/bncfreq/lists/);
    my $texts =<<"EOF";
5_1_all_rank_noun.txt
5_2_all_rank_verb.txt
5_3_all_rank_adjective.txt
5_4_all_rank_adverb.txt
5_5_all_rank_pron.txt
5_6_all_rank_determ.txt
5_7_all_rank_detpro.txt
5_8_all_rank_preposition.txt
5_9_all_rank_conjunction.txt
5_10_all_rank_interjection.txt
EOF
    my @files = split(/\n/, $texts);
    my $script;
    foreach my $f (@files){
	$script .= &download($opt_value, $URL, $f, $BNC_ALL) . "\nsleep 5\n";
    }
    $script .=<<"EOF";
#perl -pe 's/^\t(\S+).+/$1/' $BNC_ALL |sort  | uniq > $BNC_ALL
EOF

    print "$script\n";
    exit 0;
}

sub download{
    my($system, $URL, $file, $save) = @_;
    if($system eq "mac"){
	return "curl $URL/$file >> $save";	
    }elsif($system eq "linux"){
	return "curl $URL/$file >> $save";	
    }else{
	return "Please download files from $URL";
    }
}
