package PlainFileIO;

use MIME::Base64;
use Data::Dumper;

sub Dump
{
	my $dump = Dumper(shift);
	map { CL::msg($_); } split /\n/, $dump;
}

sub new
{
	my $class = shift;
	my $filename = shift;

	return bless { filename => $filename }, $class;
}

sub load($$)
{
	my $self = shift;
	my $mapper = shift;

	my $filename = $self->{filename};

	{
		# touch files in case it doesn't exist.
		open(local $rooms_file, ">>", "$filename.rooms");
		open(local $zones_file, ">>", "$filename.zones");
	}

	my $errors = 0;
	my $line = 0;
	my %zones = ();
	my $zones_counter = 0;
	open(my $zones_file, "+<", "$filename.zones") or die "Mapper couldn't open zones data file '$filename.zones'.";
	while (<$zones_file>)
	{
		chop;
		++$line;
		unless (/^(\d+);([0-9a-zA-Z+\/=]*);([0-9a-zA-Z+\/=]*)$/)
		{
			CL:msg("Line $line of zones data file is malformed. Skipping.");
			++$errors;
			CL::msg("Too many errors. Stopping load."), last if $errors > 12;
			next;
		}

		$zones{$1} = {name => decode_base64($2), notes => decode_base64($3)};
		++$zones_counter;
	}

	$line = 0;
	my $rooms_counter = 0;
	open(my $rooms_file, "+<", "$filename.rooms") or die "Mapper couldn't open rooms data file '$filename.rooms'.";
	while (<$rooms_file>)
	{
		chop;
		++$line;
		unless (/^(\d+);(\d+);((?:\w+\:\d+(?:\/\w+:\d+)*)?);([0-9a-zA-Z+\/=]*);([0-9a-zA-Z+\/=]*);([0-9a-zA-Z+\/=]*)$/)
		{
			CL::msg("Line $line of rooms data file is malformed. Skipping. $_");
			++$errors;
			CL::msg("Too many errors. Stopping load."), last if $errors > 12;
			next;
		}

		$room = {VNUM => $1, ZONE => $2, NAME => decode_base64($4), NOTES => decode_base64($5), TERRAIN => decode_base64($6)};
		$exits = $3;
		my %exits = map { split /:/ } split /\//, $exits;
		$room->{EXITS} = \%exits;
		$room->{AREA} = $zones{$room->{ZONE}}->{name};
		++$rooms_counter;

		$mapper->internal_set_room($room);
	}

	CL::msg("Loaded $zones_counter zones and $rooms_counter rooms.");
}

sub save($$)
{
	my $self = shift;
	my $mapper = shift;

	my $zones_counter = 0;
	my $filename = $self->{filename};
	open(my $zones_file, "+>", "$filename.zones") or die "Mapper couldn't open zones data file '$filename.zones'.";
	for (keys %{$mapper->{zones}})
	{
		print $zones_file sprintf("%d;%s;%s\n", $_, encode_base64($mapper->{zones}{$_}{name}, ""), encode_base64($mapper->{zones}{$_}{notes}, ""));
		++$zones_counter;
	}

	my $rooms_counter = 0;
	open(my $rooms_file, "+>", "$filename.rooms") or die "Mapper couldn't open rooms data file '$filename.rooms'.";
	for $r (keys %{$mapper->{rooms}})
	{
		my $exits = join "/", map { "$_:".$mapper->{rooms}{$r}{exits}{$_} } keys %{$mapper->{rooms}{$r}{exits}};
		print $rooms_file sprintf("%d;%d;%s;%s;%s;%s\n",
			$r,
			$mapper->{rooms}{$r}{zone},
			$exits,
			encode_base64($mapper->{rooms}{$r}{name}, ""),
			encode_base64($mapper->{rooms}{$r}{notes}, ""),
			encode_base64($mapper->{rooms}{$r}{terrain}, ""));
		++$rooms_counter;
	}

	CL::msg("Saved $zones_counter zones and $rooms_counter rooms.");
}

package Mapper;

use Data::Dumper;

sub new
{
	my $class = shift;
	my $io = shift;
	$io = new PlainFileIO("mapper.data") unless defined $io;

	local $self = bless { zones => {}, rooms => {}, io => $io }, $class;
	$self->{io}->load($self);

	return $self;
}

sub reload($)
{
	my $self = shift;

	$self->{rooms} = {};
	$self->{zones} = {};
	$self->{io}->load($self);
}

sub save($)
{
	my $self = shift;

	$self->{io}->save($self);
}

sub internal_set_room($$)
{
	my $self = shift;
	my $value = shift;

	my $old_room = undef;
	if (defined $self->{rooms}{$value->{VNUM}})
	{
		$old_room = $self->{rooms}{$value->{VNUM}};
	}
	
	$self->{rooms}{$value->{VNUM}} = {zone => $value->{ZONE}, name => $value->{NAME}, exits => $value->{EXITS}, notes => "", terrain => $value->{TERRAIN}};
	
	if (defined $old_room)
	{
		$self->{rooms}{$value->{VNUM}}->{notes} = $old_room->{notes};
	}

	if (defined $value->{NOTES})
	{
		$self->{rooms}{$value->{VNUM}}->{notes} = $value->{NOTES};
	}

	my $old_zone = undef;
	if (defined $self->{zones}{$value->{ZONE}})
	{
		$old_zone = $self->{zones}{$value->{ZONE}};
	}

	$self->{zones}{$value->{ZONE}} = {name => $value->{AREA}, rooms => [], notes => ""} unless $self->{zones}{$value->{ZONE}};

	if (defined $old_zone)
	{
		$self->{zones}{$value->{ZONE}}->{notes} = $old_zone->{notes};
	}

	if (defined $value->{ZONE_NOTES})
	{
		$self->{zones}{$value->{ZONE}}->{notes} = $value->{ZONE_NOTES};
	}

	push @{$self->{zones}{$value->{ZONE}}{rooms}}, $value->{VNUM};
}

sub set_room($$)
{
	my $self = shift;
	my $value = shift;

	$self->internal_set_room($value);
}

sub print_stats($)
{
	my $self = shift;

	CL::msg("Mapper has info about " . (scalar keys %{$self->{zones}}) . " zones and " . (scalar keys %{$self->{rooms}}) . " rooms.");
}

1;

# vim: set ts=4 sw=4 tw=0 noet syntax=perl :

