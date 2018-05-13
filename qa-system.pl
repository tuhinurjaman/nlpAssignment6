#This program created by Tuhinur Jaman
#system will try to answer Who, What, When and Where questions.
# this system will take the question through terminal. After getting the question
#we extract the question and sent the subject to the wiki. For example, #who is Barack Obama? The system defines it is it is  what type of question and it take
#BArack Obama as subject to inquiry in the wiki.
#by Using the regular expression and sentence structure, it fetches the information to make the summary of the information.
#we rewrite the question and look into a wiki and capture the answer and added with the rewrite word Barack Obama.
# reword system finds the question type,verb variations, and auxiliary verbs to generate answer patterns.
#the question input should be grammatically correct and subject first letter should be Capitalize.
# for Example if we look for Barack Obama then B and O should be capitalized.when we find the answer we compare which weight provide the most accurate answer it will provide that answer.
#('Barack Hussein Obama II' (; born August 4, 1961) is an American politician who served as the 44th President of the United States from January 20, 2009, to January 20, 2017.)
#if the system doesn't Find Barack Obama it will use back of model to search for Barack or Obama separately to find the answer.
#by using word net I expand the query and created rewrite for the selected word in the query
# In order to find the best answer among multiple candidates each I assigned a weight to each rewrite.



#  eaxmple : for query "who is George Washington?"
# 1. find out type, subject, verb, and other tokens of the question
# 2. rewrite the query as:
# * george washington was
# * george washington  is
# ....
# 3. assigne a weight to each rewrites from 0 to 10
# 4. query wikipedia for extracted subject "George Washington"
# 5. run rewrites as regular expression on text and capture candidate answer
# 6. Select the candidate answer with highest weight.

# usage : perl qa-system.pl mylogfile.txt

# type exit to quit

use strict;
use Data::Dumper;
use WWW::Wikipedia;
use open ":std", ":encoding(UTF-8)";
my %auxVerb ;#look for auxilary verb.
my @art ;#look for aritcal.
my %inquiry; # collect  all data for current que
my %reword; # collect all reword for current que
my $logFileName = $ARGV[0];#open the log file from comand line argumant.
open (my $fh, '>' ,$logFileName) or die "Could not open file '$logFileName' $!";
print "This is a QA system by Tuhinur Jaman. It will try to answer ques that start with Who, What, When or Where.
\nEnter \"exit\" to leave the program.\n \n=?> ";
#main loop.read the question and print the question.
while(<STDIN>){

    my $inquiry = $_;
    chomp;
    exit if $_ eq "exit";
    print "=> ";
    print findSolution($inquiry),"\n";

}

#generating the question answer.
sub findSolution{
    #initial  question.
    undef %inquiry ;
    $inquiry{'sub'} = ();
    $inquiry{'reword'} = ();
    $inquiry{'wikiTxts'}= ();
    $inquiry{'compeeres'}=();

    my $result ;
    my $answered = 0 ;
    #labe it if  we've found answer or not
    my $query = shift;
    print $fh "\n\n\n $query\n";
    my @symbol = tknize($query);
    costume_reword();
    inquiryReformulation();

    foreach my $subject (@{$inquiry{'sub'}}){
        my $wikiTxt = "";
        inquiryWiki($subject);
    }
    compeer();

    if(defined $inquiry{'compeeres'}){
        my @successor= sort {$b->{'value'} <=> $a->{'value'}} @{$inquiry{'compeeres'}};
        my %compr = %{@successor[0]};
        $result = "(Weight".($compr{'value'}/10).")<=>".$compr{'sentence'};
    }else{
        $result = "Sorry I don't know this Question  answer.";
    }
    print $fh Dumper(\%inquiry);
    return $result;
}

sub compeer{
    # compare the answer.
    foreach my $reword (@{$inquiry{'reword'}}){
        foreach my $sentence (@{$inquiry{'wikiTxts'}}){
            my %rewordFile = %{$reword};
            my $rewrite = $rewordFile{'reword'};
            if ( $sentence =~ /$rewrite/gm ){
                print $fh "$reword $sentence \n";
                my $word  = $rewordFile{'value'};
                my $compeer = { };
                $compeer->{'value'} = $word;
                $compeer->{'reword'} = $rewrite;
                $compeer->{'sentence'} = $sentence;
                push @{$inquiry{'compeeres'}}, $compeer;

            }
        }
      }
}

# reword the question
sub inquiryReformulation(){
    # find out all the  permutation from the  orginal words
    pergenerator(4,@{$inquiry{'symbol'}});
   # if there is no  subject
    if (scalar @{$inquiry{'symbol'}} >1){
        pergenerator(4,grep($_ ne @{$inquiry{'sub'}}[0], @{$inquiry{'symbol'}}));
        # find the permutations without stop word .
        {
        my %reword ;
        $reword{'format'} = join (' ', @{$inquiry{'symbol'}}) ;
        $reword{'value'} = 2;
        $reword{'position'} = 'n';
        my $pattern = $reword{'format'};
        $reword{'reword'} = qr/$pattern/;
        push @{$inquiry{'reword'}}, \%reword;
        }

        {
        # collect back off
        my %reword ;
        $reword{'format'} = join ('(.*\s*)', @{$inquiry{'symbol'}}) ;
        $reword{'value'} = 1;
        $reword{'position'} = 'n';
        my $pattern = $reword{'format'};
        $reword{'reword'} = qr/$pattern/;
        push @{$inquiry{'reword'}}, \%reword;
        }
    }
}

#create  all possible Permutation from given word list
sub pergenerator{
    my ($weight,@words,) = @_;
    my @res;
    # lok for the verb location
    my $verbLocation ;
    for $verbLocation (0..$#words+1){
        my %reword ;
        my @comWords = @words;
        splice @comWords, $verbLocation, 0, $inquiry{'vrb'} ;
        $reword{'position'} = 'r';
        $reword{'value'} = $weight;
        $reword{'format'} = join ' ',@comWords;
        $reword{'reword'} = qr/$reword{'format'}/;
        if ($verbLocation == 0){
            $reword{'position'} = 'l';
            $reword{'reword'} = qr/$reword{'format'}/;
        }
        push @{$inquiry{'reword'}}, \%reword;
    }


}
# go  to wiki page for  the solution and then bring back the solution.
sub inquiryWiki{
    my $query = shift;
    my $wikiTxt;
    my $wiki = WWW::Wikipedia->new(clean_html => 1 );
    my $result = $wiki->search($query);
    if (defined $result){
        if ( $result->text() ) {
        $wikiTxt = $result->text_basic();
       #remove info box  and keep this for later on to print wiki text and reorganize.
        $wikiTxt =~ s/\}\}&nbsp;\x{2013}/-/gs;
        $wikiTxt =~ s/<\/?.*?>//gs;
        $wikiTxt =~ s/\R/ /g;
        $wikiTxt =~ s/\s+/ /g;
        #remove info box
        $wikiTxt =~ s/\{\{.*\}\}//g;
        $wikiTxt =~ s/([\.?!]+)/$1\n/g;
        # print $wikiTxt;
        my @wikis = split "\n",$wikiTxt;
        push @{$inquiry{'wikiTxts'}}, @wikis ;
        }
    }

}
# tknize the que return symbol as a list of string and preprocess.
sub tknize{
    my $query = shift;
    $inquiry{'inquiry'} = $query;
    # extract subject using orthographic information
    my @vr = ($query =~ /((?<!^)[A-Z][^\s!?,]+)/g);
    my $sub =  (join " ",@vr);
    push @{$inquiry{'sub'}}, $sub;
    $query = ($query =~ s/(<S>[\s!?.])+/<S> /rg);
    $query = ($query =~ s/((?<!^)[A-Z][^\s!?,]+)/<S>/rg);

    my @symbol = ($query =~ /\s?([^,!?\s]+)/g);
    #first word of the question type(when, where, what, who)
    $inquiry{'type'}= lc $symbol[0];
    # extract verb an aux verb for each type of que
    if ($inquiry{'type'} eq 'what'){
        if (exists($auxVerb{$symbol[1]})){
          #if there is an auxilarry verb exists.
            $inquiry{'axvrb'} = $symbol[1];
            $inquiry{'vrb'} = $symbol[$#symbol];
            #improved
            @symbol = grep($_ ne $inquiry{'axvrb'}, @symbol );
        }else{
            $inquiry{'vrb'} = $symbol[1];
        }
    }elsif ($inquiry{'type'} eq 'when'){
        if (exists($auxVerb{$symbol[1]})){
           # if there is an aux verb
            $inquiry{'axvrb'} = $symbol[1];
            $inquiry{'vrb'} = $symbol[$#symbol];
            # can be improved
            @symbol = grep($_ ne $inquiry{'axvrb'}, @symbol );
    }elsif ($inquiry{'type'} eq 'who'){
            $inquiry{'vrb'} = $symbol[1];

    }elsif ($inquiry{'type'} eq 'where'){
          #add located if not
        if (exists($auxVerb{$symbol[1]})){
          #if there is an aux verb
            $inquiry{'axvrb'} = $symbol[1];
            $inquiry{'vrb'} = $symbol[$#symbol];
            @symbol = grep($_ ne $inquiry{'axvrb'}, @symbol );
        }else{
            $inquiry{'vrb'} = $symbol[1];
        }
    }else{

            $inquiry{'vrb'} = $symbol[1];
        }
    }

    # remove verb, type, aux from tokes
    @symbol = grep(lc $_ ne $inquiry{'vrb'}, @symbol );
    @symbol = grep(lc $_ ne $inquiry{'type'}, @symbol );
    @symbol = map {$_ eq '<S>'? $sub : $_} @symbol;
    $inquiry{'symbol'} = \@symbol;
    return @symbol;

}
#  specific question  rewrite
sub costume_reword{
    #who question example. "who is jesus?""
    if (lc $inquiry{'type'} eq "who"){
                my $verb = $inquiry{'vrb'};
                my $query = { };
                $query->{'rewrite'} = qr/(?i) $verb ((?:a[n]? |the )[^.]*)[.,!?]/;
                $query->{'format'} = qr/(?i) $verb ((?:a[n]? |the )[^.]*)[.,!?]/;
                $query->{'value'} = 8;

                $query->{'position'} = '';
                push @{$inquiry{'reword'}},  $query;

    }
    # what question example. "what is a Bicycle?"
    elsif (lc $inquiry{'type'} eq "what"){
            my $verb = $inquiry{'vrb'};
            my $query = { };
                my %query = ('reword'=>qr/(?i) $verb ((?:a[n]? |the |)[^.]*)[.,!?]/,'format'=>qr/(?i) $verb ((?:a[n]? |the |)[^.]*)[.,!?]/ , 'value'=>8);
                push @{$inquiry{'reword'}}, \%query;

      # when question  example. "George Washington born?"
    } elsif (lc $inquiry{'type'} eq "when"){
                #check for auxiliary verb
                my $verb = $inquiry{'vrb'};
                my $sub = $inquiry{'subject'};
                my $query = { };
                $query->{'reword'} = qr/(?i)((?:celebrated (?:on )|taking place (?:on ))[^.,!?]*)/;
                $query->{'format'} = qr/(?i)((?:celebrated (?:on )|taking place (?:on ))[^.,!?]*)/;
                $query->{'value'} = 8;
                push @{$inquiry{'reword'}}, $query;

                $query = { };
                $query->{'reword'} = qr/(?i) date of the $sub $verb ((?:before |after |on |during | )[^.]*)[.,!?]/;
                $query->{'format'} = qr/(?i) date of the $sub $verb ((?:before |after |on |during | )[^.]*)[.,!?]/;
                $query->{'value'} = 8;
                push @{$inquiry{'reword'}}, $query;
                # where  queestion. for example, "where is Bangladesh?"
    }elsif (lc $inquiry{'type'} eq "where"){
                #checking  for auxiliary verb
                my $verb = $inquiry{'vrb'};
                my $sub = $inquiry{'subject'};
                my $query = { };

                $query = { };
                $query->{'reword'} = qr/(?i)((?:located (?:in |at )?|placed (?:in )?)[^.,!?]*)/;
                $query->{'format'} = qr/(?i)((?:located (?:in |at )?|placed (?:in )?)[^.,!?]*)/;
                $query->{'value'} = 8;
               push @{$inquiry{'reword'}}, $query;
               $query = { };
                $query->{'reword'} = qr/(?i).*?_location_?.*? = ((?:in )\w*(:?\s\w*)?(?:, \w*)?)/;
                $query->{'format'} = qr/(?i).*?_location_?.*? = ((?:in )\w*(:?\s\w*)?(?:, \w*)?)/;
                $query->{'value'} = 8;
                $query->{'add'} = "in";
                push @{$inquiry{'reword'}}, $query;
                $query = { };
                $query->{'reword'} = qr/(?i)location ((?:in )\w*(:?\s\w*)?(?:, \w*)?)/;
                $query->{'format'} = qr/(?i)location ((?:in )\w*(:?\s\w*)?(?:, \w*)?)/;
                $query->{'value'} = 7;
                push @{$inquiry{'reword'}}, $query;
                $query = { };
                $query->{'reword'} = qr/(?i) is.*?((?:in )[^.,!?]*)/;
                $query->{'format'} = qr/(?i) is.*?((?:in )[^.,!?]*)/;
                $query->{'value'} = 3;
                push @{$inquiry{'reword'}}, $query;
    }

}
# uses regex to compeer answer format with wiki text take two parameter wikiTxt and Regex
sub compeerAnswer{
    my ($reword, $text) = @_;
    my %query= %{$reword};
     # reword is a hash
    # process raw text from wikipedia
    my $solution = 0 ;
    my $reword = $query{'q'};
    ($solution) = $text =~ m/$reword/gm;
    return  $solution;

}

 close $fh;
