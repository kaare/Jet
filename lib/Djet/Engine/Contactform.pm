package Djet::Engine::Contactform;

use 5.010;
use Moose;

extends 'Djet::Engine::Default';
with qw/
	Djet::Part::Flash
	Djet::Part::Update::Node
/;

=head1 NAME

Djet::Engine::Contactform

=head2 DESCRIPTION

A contactform where the user enters some basic information and a comment. This data is saved in a new node, and emailed to both the site admin and the user self.

Based on the node update role, it includes validation as chosen for the individual fields, and all edit navigation is controlled there.

=head1 METHODS

=head2 before set_base_object

Will create a new empty contactform if it's a "parent" (contactforms) basetype. If it's a "child" contactform, will display it.

=cut

after 'set_base_object' => sub  {
	my $self = shift;
	my $model = $self->model;
	my $basetype = $model->basetype_by_name('contactform') or die "No basetype: contactform";

	my $contactform;
	if ($model->basenode->basetype_id == $basetype->id) {
		$contactform = $model->basenode;
		$model->stash->{template_display} = 'view';
	} else {
		$contactform = $model->resultset('Djet::DataNode')->new({
			basetype_id => $basetype->id,
			parent_id => $model->basenode->id,
			datacolumns => {}
		});
		$self->set_object($contactform);
		$self->is_new(1);
	}
	$model->stash->{contactform} = $contactform;
};

=head2 before process_post

This is processed when the contactform is submitted. A new "child" contactform is created, and the flow proceeds to
validation.

=cut

before 'process_post' => sub  {
	my $self = shift;
	my $model = $self->model;
	my $basetype = $model->basetype_by_name('contactform') or die "No basetype: contactform";

	my $contactform = $model->resultset('Djet::DataNode')->new({
		parent_id => $model->basenode->id,
		basetype_id => $basetype->id,
		datacolumns => {},
	});
	$self->set_object($contactform);
	$model->stash->{contactform} = $contactform;
	$self->is_new(1);
};

=head2 before get_input_data

Seeds the input data name and title

=cut

before 'get_input_data' => sub {
	my ($self, $validation)=@_;
	$validation->valid->{name} = 'Contactform';
	$validation->valid->{title} = $validation->valid->{name};
};

=head2 before edit_updated

Send email to the admin and the user if the "child" contactform was actually created.

=cut

before 'edit_updated' => sub {
	my ($self, $validation)=@_;
	my $model = $self->model;
	$self->set_status_msg($model->basenode->nodedata->receipt_msg->value);
	eval { $self->send_mail };
	$model->log->error("Couldn't send email: $@") if $@;
};

=head2 send_mail

Actually send the email to

 - The owner emails: nodedata->recipient
 - The user: in_fields->email

=cut

sub send_mail {
	my $self = shift;
	my $mailer = $self->mailer;
	my $model = $self->model;
	my $nodedata = $model->basenode->nodedata;
	my $in_fields = $self->object->nodedata;
	my $owners = $nodedata->recipient->value;
	my @to = ref $owners eq 'ARRAY' ? @$owners : $owners;
	push @to, $in_fields->email->value;
	$model->stash->{template_display} = 'view';
	$self->object->discard_changes;
	$model->stash->{contactform} = $self->object;
	$mailer->send(
		template => $nodedata->template->value,
		to => \@to,
		from => $nodedata->from->value,
	);
}

__PACKAGE__->meta->make_immutable;

# COPYRIGHT

__END__
