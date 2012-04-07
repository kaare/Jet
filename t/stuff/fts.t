#!/usr/bin/env perl

use 5.010;
use strict;
use warnings;

use Test::More;

use lib 't/lib';
use Test;

use_ok('Jet::Stuff');

my $stuff = Test::schema;

ok(my $data = $stuff->insert({basetype_id=>6,parent_id=>6,title=>'Family Photo',columns=>'{"test"}'},{returning => '*'}), 'Insert node');
isa_ok($stuff, 'Jet::Stuff', 'It\'s a Plane, it\'s a bird. No...');
ok(my $rows = $stuff->ft_search_node('test a rossa'), 'Fulltext search');
is(@$rows, 1, 'Number of rows');
is($rows->[0]->{title}, 'Family Photo', 'The row title');
ok(my $row = $stuff->row($rows->[0], 'domain'), 'Get 1st row as an object');
is($row->get_column('title'), 'Family Photo', 'The row title');
is($row->get_column('id'), $data->{id}, 'Row id');
ok(my $columns = $row->get_columns, 'Get columns');
use Data::Dumper;
warn Dumper $columns, $row;
is($row->num_columns, 4, 'Number of columns');
ok($stuff->delete({id => $data->{id}}), 'Remove dnode');

done_testing();
