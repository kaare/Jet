#!/usr/bin/env perl

use 5.010;
use strict;
use warnings;

use Test::More;

use_ok('Jet::Engine');

my $dbh;

my %ci = (
	dbname => 'album',
	username => 'kaare',
	password => undef,
	connect_options => {
		AutoCommit => 1,
		quote_char => '"',
		RaiseError => 1,
		pg_enable_utf8 => 1,
	},
);

ok(my $engine = Jet::Engine->new(%ci), 'Start your engines!');
isa_ok($engine, 'Jet::Engine', 'It\'s a Plane, it\'s a bird. No...');

ok(my $rows = $engine->search('domain', {id => 1}), 'Search domain');
use Data::Dumper;
warn Dumper $rows;
ok(my $result = $engine->result($rows), 'Result');
warn Dumper $result->rows;

my $row = $result->next;
my $id = $row->get_column('id');
warn Dumper $id, $row->get_columns, $row->num_columns;

done_testing();
