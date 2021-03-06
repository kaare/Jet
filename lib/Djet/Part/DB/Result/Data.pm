package Djet::Part::DB::Result::Data;

use 5.010;
use Moose::Role;
use namespace::autoclean;
use vars qw($AUTOLOAD);

=head1 NAME

Djet::Part::DB::Result::Data

=head1 DESCRIPTION

Common methods for data and datanodes.

=cut

=head2 field_inflate

Specific inflating for each field

=cut

sub field_inflate {
	my ($self, $data) = @_;
	my $fields = $self->datacolumns;
	while (my ($name, $value) = each %$data) {
		die "No field $name for datanode " . $self->id unless my $field = $fields->can($name);

		$data->{$name} = $fields->$field->unpack($value);
	}
}

=head1 ATTRIBUTES

=head2 nodedata

A Djet::NodeData object filled with the datacolumns data

=cut

has 'nodedata' => (
	is => 'ro',
	isa => 'Djet::NodeData',
	lazy_build => 1,
);

sub _build_nodedata {
	my $self= shift;
	my $model = $self->result_source->schema;
	my $basetype = $model->basetypes->{$self->basetype_id};
	return $basetype->nodedata->new(
		model => $model,
		node =>  $self,
		datacolumns =>  $self->datacolumns,
	);
}

=head2 field_deflate

Specific deflating for each field

=cut

sub field_deflate {
	my ($self, $datacol) = @_;
	my $fields = $self->datacolumns;
	while (my ($name, $value) = each %$datacol) {
		die "No field $name for datanode " . $self->id unless my $field = $fields->can($name);

		$datacol->{$name} = $fields->$field->pack($value);
	}
}

=head2 fts_text

Returns a text with all the searchable fields catenated

=cut

sub fts_text {
    my $self = shift;
	my $fts = $self->title;
	for my $field (@{ $self->nodedata->fields }) {
		next unless $field->searchable;

		$fts .= ' ' . ($field->for_search // '');
	}
    if ($self->nodedata->can('additional_fts')) {
        $fts .=  ' ' . $self->nodedata->additional_fts;
    }
    return $fts;
}

=head2 update_fts

Update the fts columns with the relevant data.

From the datanode, all the 'searchable' fields are indexed.
If the connected nodedata (<project>::Part::NodeData::<basetype name>) has an
'additional_fts' method, it can inject text to be indexed.

update_fts takes one optional parameter, the config. If not given, 'english' is assumed.

=cut

sub update_fts {
	my ($self, $config) = @_;

    my $text = $self->fts_text;

	$config ||= 'english';
	$text =~ s/[,-\/:)(']/ /g;
	$text = lc $text;
	my $q = qq{to_tsvector('$config', '$text')};
	$self->update({fts => \$q });
}

=head2 autoload

Method calls are checked to see if they match a JSON column. If so, they're handled as ordinary accessors

=cut

sub AUTOLOAD {
	my $self = shift;
	$AUTOLOAD =~ /::(\w+)$/;
	my $method = $1;
	return if $method eq 'nodedata';

	my $nodedata = $self->nodedata or return;
	die "No field $method for datanode " . $self->id unless my $field = $nodedata->can($method);

	return $nodedata->$field(@_);
}

no Moose::Role;

1;

# COPYRIGHT

__END__
