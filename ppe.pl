#!/usr/local/bin/perl

# PSP PBP editor by Perl
# Version: 1.1.1
# http://classg.sytes.net

use strict;
use warnings;

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

use PSP::PBPh;
use PSP::PBPParser;
use PSP::PBPMaker;

sub LIST   { 'LIST' }
sub CREATE { 'CREATE' }
sub REWRITE{ 'REWRITE' }
sub EXTRACT{ 'EXTRACT' }

if   ( not defined $ARGV[0] ){ usage(); }
elsif( scalar( @ARGV ) < 1 ) { error("Not enought arguments"); }

my $ope      = shift @ARGV || '';
$ope = uc( $ope );

switch:{
	
	( $ope eq LIST    ) and do{ list   ( @ARGV ); last; };
	( $ope eq CREATE  ) and do{ create ( @ARGV ); last; };
	( $ope eq REWRITE ) and do{ rewrite( @ARGV ); last; };
	( $ope eq EXTRACT ) and do{ extract( @ARGV ); last; };
	
	usage();
}

#------------------------------------------------
sub error{
	my $err = shift;
	$err =~ s/_VAR_/shift/eg if( scalar( @_ ) );
	die "Error: $err" . ".\n";
}

sub usage{
	die <<_USAGE_;
PSP PBP editor by Perl.

Usage: perl ppe.pl [operation] Target_PBP_File
    
    operation:
      list            Displaying files list in the Target_PBP_File.
      help | -h       Displaying help document. (It is this)
      extract CONTROL Extract the Target_PBP_File to CONTROL's PATH directory.
      create CONTROL  Create new PBP file.
                      (In this case, Target_PBP_File is new PBP file name.
                       So, -o option will ignore.)
      rewrite CONTROL Replace (or insert) some files in the Target_PBP_File.

    CONTROL:
      -p PATH  PARAM.SFO. This is PBP metadata file. (Required)
      -m PATH  ICON0.PNG. This is main icon image.
      -a PATH  ICON1.PMF. This is animation icon file.
      -f PATH  PIC0.PNG.  This is floating image on the background image.
                           (This is overlaid by the PIC1.PNG)
      -b PATH  PIC1.PNG.  This is background image.
      -s PATH  SND0.AT3.  This is background music.
      -0 PATH  DATA.PSP.
      -1 PATH  DATA.PSAR.

      (If you set PATH to "none" then it will remove from the Target_PBP_File.)
      
      for "rewrite" and "extract" operation:
      -o PATH  Output directory path.
               In rewrite:
                 Required *FILE* path.
                 The "rewrite" create a new PBP file to PATH.
                 (It is overwrite the Target_PBP_File by default)
               In extract:
                 Required *DIRECTORY* path.
                 The "extract" extract all files to PATH directory.
                 (And other options is IGNORED)
_USAGE_
}

sub normalize_keys{
	my $args = shift;
	
	my @args_keys = keys %{$args};
	my $pbp_fname = '';
	foreach( @args_keys ){
		detect_keyname:{
			( $_ eq '-p' ) and do{ $pbp_fname = 'param';  last; };
			( $_ eq '-m' ) and do{ $pbp_fname = 'icon0';  last; };
			( $_ eq '-a' ) and do{ $pbp_fname = 'icon1';  last; };
			( $_ eq '-f' ) and do{ $pbp_fname = 'pic0';   last; };
			( $_ eq '-b' ) and do{ $pbp_fname = 'pic1';   last; };
			( $_ eq '-s' ) and do{ $pbp_fname = 'snd0';   last; };
			( $_ eq '-0' ) and do{ $pbp_fname = 'psp';    last; };
			( $_ eq '-1' ) and do{ $pbp_fname = 'psar';   last; };
			
			( $_ eq '-o' ) and do{ last; };
			
			error( "Illegal CONTROL \"_VAR_\"", $_ );
		}
		
		if( $pbp_fname ){
			$args->{$pbp_fname} = $args->{$_} ne 'none' ? $args->{$_} : '';
			$args->{$pbp_fname} =~ tr/\\/\//;
			delete $args->{$_};
		} else{
			$args->{$_} =~ tr/\\/\//;
		}
	}
	
	return 1;
}

sub list{
	my $file = pop || '';
	
	my $Pbp  = PSP::PBPParser->new( $file )->parse_header;
	error( $Pbp->error ) if( $Pbp->error );
	
	printf( '% 10s', 'FILENAME' );
	printf( '% 13s', 'LENGTH(B)' );
	printf( '% 13s', 'LENGTH(MB)' );
	printf( '% 13s', 'OFFSET(DEC)' );
	printf( '% 13s', 'OFFSET(HEX)' );
	print "\n";
	foreach( PBP_DATA_SEQUENCE ){
		next if( not $Pbp->flen( $_ ) );
		printf( '% 10s'   , pbp_name2label( $_ ) );
		printf( '% 13d'   , $Pbp->flen( $_ ) );
		printf( '% 13.2f' , $Pbp->flen( $_ ) / (1024 * 1024) );
		printf( '% 13d'   , $Pbp->foffset( $_ ) );
		printf( '% 13X'   , $Pbp->foffset( $_ ) );
		print "\n";
	}
}

sub create{
	my $new_pbp_path = pop;
	
	error("Not enoght \"create\" arguments",) if( scalar( @_ ) % 2 );
	
	my %files = ( @_ );
	normalize_keys( \%files );
	
	my $Newpbp = PSP::PBPMaker->new( $new_pbp_path );
	$Newpbp->set( $_, ( $files{$_} || '' ) ) foreach( PBP_DATA_SEQUENCE );
	print "Writing to $new_pbp_path.\n";
	$Newpbp->make;
}

sub rewrite{
	my $src_pbp_path = pop;
	
	error("Not enoght \"rewrite\" arguments",) if( scalar( @_ ) % 2 );
	
	my %files  = ( @_ );
	normalize_keys( \%files );
	
	if( exists $files{'-o'} ){
		$files{'-o'} ||= '.';
	} else{
		$files{'-o'} = $src_pbp_path;
	}
	
	my $workdir = '';
	{
		if( $files{'-o'} =~ /\// ){
			$workdir = substr( $files{'-o'}, 0, rindex( $files{'-o'}, '/' ) ) || '';
			error( "\"_VAR_\" is not exist", $workdir ) if( not -d $workdir );
		}
		$workdir = '.' if( $workdir eq '' );
	}
	
	my $Srcpbp = PSP::PBPParser->new( $src_pbp_path )->parse_header;
	error( $Srcpbp->error ) if( $Srcpbp->error );
	
	my $Newpbp = PSP::PBPMaker->new( $files{'-o'} );
	my @extract_items;
	print "Checking CONTROL:\n";
	foreach( PBP_DATA_SEQUENCE ){
		print "    " . pbp_name2label( $_ ) . ": "; 
		if( exists $files{$_} ){
			$Newpbp->set( $_, $files{$_} );
			print ( $files{$_} ? "rewrite to $files{$_}" : "remove" );
		} elsif( $Srcpbp->flen( $_ ) ){
			push( @extract_items, $_ );
			print "divert"
		} else{
			print "none";
		}
		print "\n";
	}
	
	
	my ( $tmpname, @tmpfiles );
	$tmpname = time;
	print "Extract diverting tempfiles:\n" if( scalar( @extract_items ) );
	foreach( @extract_items ){
		$tmpname++;
		$Newpbp->set( $_, "$workdir/temp_$tmpname" );
		$Srcpbp->output( $_, $Newpbp->get( $_ ) );
		push( @tmpfiles, $Newpbp->get( $_ ) );
	}
	print "    " . join( "\n    ", @tmpfiles ) . "\n";
	
	print "Rewriting to $files{'-o'}.\n";
	$Newpbp->make;
	
	if( scalar( @tmpfiles ) ){
		unlink( @tmpfiles );
		print "Removed diverting tempfiles.\n";
	}
}

sub extract{
	my $src_pbp_path = pop;
	
	my %files;
	
	for( my $i = 0; $i < scalar( @_ ); $i++ ){
		if( substr( $_[$i], 0, 1 ) eq '-' ){
			if( defined $_[$i + 1] and ( substr( $_[$i + 1], 0, 1 ) ne '-' ) ){
				$files{$_[$i]} = $_[$i + 1];
				$i++;
			} else{
				$files{$_[$i]} = '';
			}
		}
	}
	normalize_keys( \%files );
	foreach( keys %files ){
		next if( substr( $_, 0, 1 ) eq '-' );
		$files{$_} = './' . pbp_name2label( $_ ) if( $files{$_} eq '' );
	}
	
	if( exists $files{'-o'} or not scalar( keys %files ) ){
		$files{'-o'} ||= '.';
		error( "\"_VAR_\" is not a directory", $files{'-o'} ) if( not -d $files{'-o'} );
		$files{$_} = $files{'-o'} . '/' . pbp_name2label( $_ ) foreach( PBP_DATA_SEQUENCE );
	} else{
		my $tmp;
		foreach( keys %files ){
			error( "\"_VAR_\" is directory", $files{$_} ) if( -d $files{$_} );
			
			if( $files{$_} =~ /\// ){
				$tmp = substr( $files{$_}, 0, rindex( $files{$_}, '/' ) );
				error( "\"_VAR_\" is not exist", $tmp ) if( not -d $tmp );
			}
		}
	}
	
	my $Pbp = PSP::PBPParser->new( $src_pbp_path )->parse_header;
	error( $Pbp->error ) if( $Pbp->error );
	
	foreach( keys %files ){
		next if( not $Pbp->flen( $_ ) );
		print "Extracting " . pbp_name2label( $_ ) . " to $files{$_} ...\n";
		$Pbp->output( $_, $files{$_} );
	}
}

__END__