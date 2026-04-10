package PSP::PBPh;

# PSP PBP shared module
# Version: 1.0.0
# http://classg.sytes.net

use vars qw(@ISA @EXPORT);
use Exporter;
@ISA = qw(Exporter);

@EXPORT = qw(
	PBP_VERSION
	PBP_DATA_SEQUENCE
	PBP_DATA_LABELS
	pbp_name2label
);

sub PBP_VERSION      { "\x00\x00\x01\x00" }

sub PBP_DATA_SEQUENCE{
	return (qw/
		param
		icon0
		icon1
		pic0
		pic1
		snd0
		psp
		psar
	/)
}

sub PBP_DATA_LABELS{
	return (qw/
		PARAM.SFO
		ICON0.PNG
		ICON1.PNG
		PIC0.PNG
		PIC1.PNG
		SND0.AT3
		DATA.PSP
		DATA.PSAR
	/)
}

sub pbp_name2label{
	my $name = shift;
	my $idx = 0;
	
	foreach( PBP_DATA_SEQUENCE ){
		return (PBP_DATA_LABELS)[$idx] if( $_ eq $name );
		$idx++;
	}
	
	return 0;
}

1;
__END__