package MSDP;

require MUD;
require CL;

use Data::Dumper;

$MSDP_OPT = "\x45";

$MSDP_VAR = "\x1";
$MSDP_VAL = "\x2";

$MSDP_TABLE_OPEN = "\x3";
$MSDP_TABLE_CLOSE = "\x4";

$MSDP_ARRAY_OPEN = "\x5";
$MSDP_ARRAY_CLOSE = "\x6";

$TELNET_IAC = "\xff";
$TELNET_SB = "\xfa";
$TELNET_SE = "\xf0";

sub report($)
{
	local $var = shift;
	CL::msg("Sending MSDP request to report variable $var");
	MUD::sendr("$TELNET_IAC$TELNET_SB$MSDP_OPT$MSDP_VAR" . "REPORT$MSDP_VAL$var$TELNET_IAC$TELNET_SE");
}

sub MSDP_Init
{
	CL::msg("Initializing MSDP.");
}

sub parse_msdp_var($$);
sub parse_msdp_array($$)
{
	my ($data, $offset) = @_;

	++$$offset; # skip MSDP_ARRAY_OPEN

	local @result = ();
	do
	{
		if ($MSDP_VAL ne substr($data, $$offset, 1))
		{
			CL::msg("Expected MSDP_VAL not found in the array at offset $$offset. Got " . ord($data[$$offset]) . ".");
			return undef;
		}
		++$$offset;

		my $start_val = $$offset;
		++$$offset while $$offset < length $data && substr($data, $$offset, 1) ne $MSDP_VAL;

		if ($$offset == length $data)
		{
			CL::msg("Unexpected end of MSDP array.");
			return undef;
		}

		push @result, substr $data, $start_val, $$offset - $start_val;
	} while (substr($data, $$offset, 1) ne $MSDP_ARRAY_CLOSE);
	++$$offset;

	return \@result;
}

sub parse_msdp_table($$)
{
	my ($data, $offset) = @_;
	local %result = ();

	++$$offset; # skip MSDP_TABLE_OPEN

	do
	{
		unless ($MSDP_VAR eq substr($data, $$offset, 1))
		{
			CL::msg("Expected MSDP_VAR not found in the table at offset $$offset. Got " . ord(substr $data, $$offset, 1) . ".");
			return undef;
		}

		local $entry = parse_msdp_var($data, $offset);
		return undef if not $entry || not %$entry;

		%result = (%result, %$entry);

		if ($$offset == length $data)
		{
			CL::msg("Unexpected end of MSDP table.");
			return undef;
		}
	} while (not substr($data, $$offset, 1) eq $MSDP_TABLE_CLOSE);
	++$$offset;

	return \%result;
}

sub parse_msdp_var($$)
{
	my ($data, $offset) = (shift, shift);

	if (not $MSDP_VAR eq substr($data, $$offset, 1) || $$offset == length $data)
	{
		CL::msg("Character at offset $$offset is not expected MSDP_VAR but " . ord(substr($data, $$offset, 1)) . " encountered.");
		return undef;
	}

	my $var_start = 1 + $$offset;
	++$$offset while ($$offset < length $data && substr($data, $$offset, 1) ne $MSDP_VAL);
	if ($$offset == length $data)
	{
		CL::msg("Unexpected end of MSDP variable.");
		return undef;
	}
	my $name = substr $data, $var_start, $$offset - $var_start;

	++$$offset;
	local %result = {};
	if ($$offset == length $data)
	{
		%result = ($name => "");
		return \%result;
	}

	if ($MSDP_ARRAY_OPEN eq substr($data, $$offset, 1))
	{
		%result = ($name => parse_msdp_array($data, $offset));
		return \%result;
	}

	if ($MSDP_TABLE_OPEN eq substr($data, $$offset, 1))
	{
		%result = ($name => parse_msdp_table($data, $offset));
		return \%result;
	}

	my $start_val = $$offset;
	++$$offset while $$offset < length $data && substr($data, $$offset, 1) ne $MSDP_ARRAY_CLOSE && substr($data, $$offset, 1) ne $MSDP_TABLE_CLOSE && substr($data, $$offset, 1) ne $MSDP_VAR;
	%result = ($name => substr $data, $start_val, $$offset - $start_val);

	return \%result;
}

my %handlers = ();
sub handler(&$)
{
	CL::msg("Setting MSDP handler.");
	local $function = shift;
	local $id = shift;
	$handlers{$id} = $function;
}

sub MSDP_Data($)
{
	my $data = shift;
	my $s = unpack "H*", $data;

	return undef unless substr($data, 0, 1) eq $MSDP_OPT;

	local $offset = 1;
	my $result = parse_msdp_var($data, \$offset);
	CL::msg("MSDP data malformed at offset $offset. Result: " . Dumper(\%result)), return undef if length $data != $offset;

	for (keys %handlers)
	{
		&{$handlers{$_}}($result);
	}
}

MUD::register_telopt_handler(\&MSDP_Init, \&MSDP_Data, 0x45, "MSDP");

1;

# vim: set ts=4 sw=4 tw=0 noet syntax=perl :

