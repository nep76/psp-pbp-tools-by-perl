#!/usr/local/bin/perl

# PSP PBP viewer by Perl
# http://classg.sytes.net

BEGIN{
	my $self = $0;
	$self =~ s/\\/\//g;
	if( $self =~ /\// ){
		$self = substr( $self, 0, rindex( $self, '/' ) );
	} else{
		$self = '.' ;
	}
	push( @INC, "$self/module" );
}

#use strict;
#use warnings;
use vars qw( $VERSION );

use PSP::PBP::Const;
use PSP::PBP::Parser;

$VERSION = "2.0.0";

if( scalar @ARGV < 1 ){
	die <<_USAGE_;
PSP PBP viewer by Perl.

Usage: pbplist.pl PBP_FILE
_USAGE_
}

die( "$ARGV[0] not found.\n" ) if( not -f $ARGV[0] );

my $PBP = PSP::PBP::Parser->new( $ARGV[0] );
$PBP->parse;
die( $PBP->error ."\n" ) if( $PBP->error );

printf( '% 10s', 'FILENAME' );
printf( '% 14s', 'LENGTH(B)' );
printf( '% 14s', 'LENGTH(MB)' );
printf( '% 14s', 'OFFSET(DEC)' );
printf( '% 14s', 'OFFSET(HEX)' );
print "\n";

foreach( PBP_STRUCT_SEQ ){
	next if( not $PBP->len( $_ ) );
	printf( '% 10s'   , $_);
	printf( '% 14s'   , comma( $PBP->len( $_ ) ) );
	printf( '% 14.2f' , $PBP->len( $_ ) / (1024 * 1024) );
	printf( '% 14s'   , comma( $PBP->offset( $_ ) ) );
	printf( '% 14X'   , $PBP->offset( $_ ) );
	print "\n";
}

sub comma
{
	my $digit = shift;
	1 while $digit =~ s/(.*\d)(\d\d\d)/$1,$2/g;
	return $digit;
}

__END__