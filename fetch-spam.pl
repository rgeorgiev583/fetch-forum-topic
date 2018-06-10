#!/usr/bin/perl

use strict;
use warnings;

use LWP::Simple;

use constant SPAM_STEP => 15;

die 'No maximum page number specified' if not scalar @ARGV;
my $spam_max_page_number         = shift @ARGV;
my $spam_target_directory        = scalar @ARGV ? shift @ARGV : '.';
my $spam_topic_page_url_template = scalar @ARGV ? shift @ARGV : 'http://forum.animes-bg.com/viewtopic.php?f=18&t=75541&start=';

for my $spam_page_number (1 .. $spam_max_page_number) {
    open(my $spam_fh, '>:encoding(UTF-8)', "${spam_target_directory}/${spam_page_number}.html");
    my $spam_offset = SPAM_STEP * ($spam_page_number - 1);
    print $spam_fh get "${spam_topic_page_url_template}${spam_offset}";
    close $spam_fh;
}
