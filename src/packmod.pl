sub mfind {
	my $mod=shift;
	for my $p (@INC) {
		return "$p/$mod" if (-r "$p/$mod");
	}
	return undef;
}

push(@INC,$ENV{srcdir}) if $ENV{srcdir};
select(STDOUT);
$|=1;

print <<EOF
#include <stdlib.h>

static struct {
	int			origsize;
	int			packedsize;
	const char	*name;
	const char	*moddata;
} perlmodules[]={
EOF
;

my $B2C = "./b2c";

for my $m (@ARGV) {
	print "// $m\n";
	if ("--b2c" eq $m)
	{
		$B2C = undef;
		next;
	}
	unless (defined $B2C)
	{
		$B2C = $m;
		next;
	}

	my $mod=$m;
	$mod =~ s/::/\//g;
	my $ext="";
	$ext=".pm" unless $mod =~ /\.p[ml]$/s;
	my $f;
	if ($mod =~ /^(.*)=(.*)$/) {
		$mod=$1;
		$f=$2;
		print "// $f does not exist", die "$f does not exist" unless -r $f;
	} else {
		$f=mfind($mod . $ext);
		print "// Can't find $mod in \@INC\n", die "Can't find $mod in \@INC\n" if (!$f);
	}
	print "// $B2C $f $mod\n";
	system("$B2C $f $mod");
	die "b2c failed: $?\n" if ($?);
}

print <<EOF
};

#define	NMOD	(sizeof(perlmodules)/sizeof(perlmodules[0]))

int		get_packed_module_data(int idx,const char **name,const char **pdata,
								int *osize,int *psize) {
	if (idx<0 || (size_t)idx>=NMOD)
		return 0;
	*name=perlmodules[idx].name;
	*pdata=perlmodules[idx].moddata;
	*osize=perlmodules[idx].origsize;
	*psize=perlmodules[idx].packedsize;
	return 1;
}
EOF
;
