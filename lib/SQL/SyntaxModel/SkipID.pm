=head1 NAME

SQL::SyntaxModel::SkipID - Use SQL::SyntaxModels without inputting Node IDs

=cut

######################################################################

package SQL::SyntaxModel::SkipID;
use 5.006;
use strict;
use warnings;
use vars qw($VERSION);
$VERSION = '0.30';

use Locale::KeyedText 0.06;
use SQL::SyntaxModel 0.40;

use base qw( SQL::SyntaxModel );

######################################################################

=head1 DEPENDENCIES

Perl Version: 5.006

Standard Modules: I<none>

Nonstandard Modules: 

	Locale::KeyedText 0.06 (for error messages)
	SQL::SyntaxModel 0.40 (parent class)

=head1 COPYRIGHT AND LICENSE

This module is Copyright (c) 1999-2004, Darren R. Duncan.  All rights reserved.
Address comments, suggestions, and bug reports to B<perl@DarrenDuncan.net>, or
visit "http://www.DarrenDuncan.net" for more information.

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl 5.8 itself.

Any versions of this module that you modify and distribute must carry prominent
notices stating that you changed the files and the date of any changes, in
addition to preserving this original copyright notice and other credits.  This
module is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE.

=cut

######################################################################
######################################################################

# These are duplicate declarations of some properties in the SQL::SyntaxModel parent class.
my $CPROP_ALL_NODES   = 'all_nodes';

# These are Container properties that SQL::SyntaxModel::SkipID added:
my $CPROP_LAST_NODES = 'last_nodes'; # hash of node refs; find last node created of each node type

# More duplicate declarations:
my $ATTR_ID      = 'id'; # attribute name to use for the node id

# These named arguments are used with the create_[/child_]node_tree[/s]() methods:
my $ARG_NODE_TYPE = 'NODE_TYPE'; # str - what type of Node we are
my $ARG_ATTRS     = 'ATTRS'; # hash - our attributes, including refs/ids of parents we will have
my $ARG_CHILDREN  = 'CHILDREN'; # list of refs to new Nodes we will become primary parent of

# This constant is used by the related node searching feature, and relates 
# to the %NODE_TYPES_EXTRA_DETAILS hash, below.
my $S = '.'; # when same node type directly inside itself, make sure on parentmost of current
my $P = '..'; # means go up one parent level
my $HACK1 = '[]'; # means use [view_src.name+table_col.name] to find a view_src_col in current view_rowset

my %NODE_TYPES_EXTRA_DETAILS = (
	'catalog' => {
		'link_search_attr' => 'name',
		'def_attr' => 'id',
	},
	'application' => {
		'link_search_attr' => 'name',
		'def_attr' => 'id',
	},
	'owner' => {
		'link_search_attr' => 'name',
		'def_attr' => 'id',
	},
	'schema' => {
		'link_search_attr' => 'name',
		'def_attr' => 'id',
		'attr_defaults' => {
			'name' => ['lit','data'],
			'owner' => ['last'],
		},
	},
	'domain' => {
		'link_search_attr' => 'name',
		'def_attr' => 'base_type',
		'attr_defaults' => {
			'base_type' => ['lit','STR_CHAR'],
		},
	},
	'sequence' => {
		'link_search_attr' => 'name',
		'def_attr' => 'name',
	},
	'table' => {
		'link_search_attr' => 'name',
		'def_attr' => 'name',
	},
	'table_col' => {
		'link_search_attr' => 'name',
		'def_attr' => 'name',
		'attr_defaults' => {
			'mandatory' => ['lit',0],
		},
	},
	'table_ind' => {
		'search_paths' => {
			'f_table' => [$P,$P], # match child table in current schema
		},
		'link_search_attr' => 'name',
		'def_attr' => 'name',
	},
	'table_ind_col' => {
		'search_paths' => {
			'table_col' => [$P,$P], # match child col in current table
			'f_table_col' => [$P,'f_table'], # match child col in foreign table
		},
		'def_attr' => 'table_col',
	},
	'view' => {
		'link_search_attr' => 'name',
		'def_attr' => 'name',
		'attr_defaults' => {
			'view_type' => ['lit','MULTIPLE'],
		},
	},
	'view_src' => {
		'search_paths' => {
			'match_table' => [$P,$S,$P], # match child table in current schema
			'match_view' => [$P,$S,$P], # match child view in current schema
		},
		'link_search_attr' => 'name',
		'def_attr' => 'name',
	},
	'view_src_col' => {
		'search_paths' => {
			'match_table_col' => [$P,'match_table'], # match child col in other table
			'match_view_col' => [$P,'match_view'], # match child col in other view
		},
		'link_search_attr' => 'match_table_col',
		'def_attr' => 'match_table_col',
	},
	'view_col' => {
		'link_search_attr' => 'name',
		'def_attr' => 'name',
	},
	'view_join' => {
		'search_paths' => {
			'lhs_src' => [$P], # match child view_src in current view_rowset
			'rhs_src' => [$P], # match child view_src in current view_rowset
		},
	},
	'view_join_col' => {
		'search_paths' => {
			'lhs_src_col' => [$P,'lhs_src',['table_col',[$P,'match_table']]], # ... recursive code
			'rhs_src_col' => [$P,'rhs_src',['table_col',[$P,'match_table']]], # ... recursive code
		},
	},
	'view_expr' => {
		'search_paths' => {
			'view_col' => [$S,$P,$S], # match child col in current view
			'src_col' => [$S,$P,$HACK1,['table_col',[$P,'match_table']]], # match a src+table_col in current schema
			'call_view' => [$S,$P,$S,$P], # match child view in current schema
			'call_ufunc' => [$S,$P,$S,$P], # match child routine in current schema
		},
	},
	'routine' => {
		'link_search_attr' => 'name',
		'def_attr' => 'name',
	},
	'routine_arg' => {
		'link_search_attr' => 'name',
		'def_attr' => 'name',
	},
	'routine_var' => {
		'search_paths' => {
			'domain' => [$P,$S,$P,$P,$P], # match child datatype of root
			'curs_view' => [$P,$S,$P], # match child view in current schema
		},
		'link_search_attr' => 'name',
		'def_attr' => 'name',
	},
	'routine_stmt' => {
		'search_paths' => {
			'block_routine' => [$P], # link to child routine of current routine
			'dest_var' => [$P], # match child routine_var in current routine
		},
	},
	'routine_expr' => {
		'search_paths' => {
			'routine_var' => [$S,$P,$P], # match child routine_var in current routine
			'call_ufunc' => [$S,$P,$S,$P,$P], # match child routine in current schema
		},
	},
);

######################################################################
# Overload these wrapper methods of parent so created objects blessed into subclasses.

sub new_container {
	return( SQL::SyntaxModel::SkipID::Container->new() );
}

sub new_node {
	return( SQL::SyntaxModel::SkipID::Node->new( $_[1] ) );
}

######################################################################
######################################################################

package SQL::SyntaxModel::SkipID::Container;
#use base qw( SQL::SyntaxModel::SkipID SQL::SyntaxModel::Container );
use vars qw( @ISA );
@ISA = qw( SQL::SyntaxModel::SkipID SQL::SyntaxModel::Container );

######################################################################

sub new {
	my ($class) = @_;
	my $container = $class->SUPER::new();
	my $node_types = $container->valid_node_types();
	$container->{$CPROP_LAST_NODES} = { map { ($_ => undef) } keys %{$node_types} };
	return( $container );
}

######################################################################

sub create_node_tree {
	my ($container, $args) = @_;
	defined( $args ) or $container->_throw_error_message( 'SSMSID_C_CR_NODE_TREE_NO_ARGS' ); # same er as p

	unless( ref( $args ) eq 'HASH' ) {
		$args = { $ARG_NODE_TYPE => $args };
	}

	my $node = $container->new_node( $args->{$ARG_NODE_TYPE} );

	my $node_type = $node->get_node_type();

	$node->get_node_id() or 
		$node->set_node_id( $container->get_next_free_node_id( $node_type ) );

	$node->put_in_container( $container );
	$node->add_reciprocal_links();
	$node->set_attributes( $args->{$ARG_ATTRS} ); # handles all attribute types; may override autogen node id

	unless( $node->get_parent_node() ) {
		$container->_create_node_tree__do_when_parent_not_set( $node );
	}

	$node->test_deferrable_constraints();

	$container->{$CPROP_LAST_NODES}->{$node_type} = $node; # assign reference

	$node->create_child_node_trees( $args->{$ARG_CHILDREN} );

	return( $node );
}

sub _create_node_tree__do_when_parent_not_set {
	# Called either if a PARENT arg not given, or if it matched nothing.
	my ($container, $node) = @_;
	my $node_type = $node->get_node_type();
	$node->node_types_with_pseudonode_parents( $node_type ) and return( 1 );
	foreach my $attr_name (@{$node->valid_node_type_parent_attribute_names( $node_type )}) {
		my $exp_node_type = $node->valid_node_type_node_ref_attributes( $node_type, $attr_name );
		if( my $parent = $container->{$CPROP_LAST_NODES}->{$exp_node_type} ) {
			# The following two lines is what the old _make_child_to_parent_link did.
			$node->set_node_ref_attribute( $attr_name, $parent );
			$node->set_parent_node_attribute_name( $attr_name );
			last;
		}
	}
	# If $node->get_parent_node() still has failed to be set, then the subsequent 
	# call to $node->test_deferrable_constraints() will throw an exception citing it.
}

sub create_node_trees {
	my ($container, $list) = @_;
	$list or return( undef );
	unless( ref($list) eq 'ARRAY' ) {
		$list = [ $list ];
	}
	foreach my $element (@{$list}) {
		$container->create_node_tree( $element );
	}
}

######################################################################
######################################################################

package SQL::SyntaxModel::SkipID::Node;
#use base qw( SQL::SyntaxModel::SkipID SQL::SyntaxModel::Node );
use vars qw( @ISA );
@ISA = qw( SQL::SyntaxModel::SkipID SQL::SyntaxModel::Node );

######################################################################

sub set_node_ref_attribute {
	my ($node, $attr_name, $attr_value) = @_;
	eval {
		$node->SUPER::set_node_ref_attribute( $attr_name, $attr_value );
	};
	if( my $exception = $@ ) {
		if( $exception->get_message_key() eq 'SSM_N_SET_NREF_AT_BAD_ARG_VAL' ) {
			# We were given a non-Node and non-Id $attr_value.
			# Now look for something we can actually use for a value.
			$attr_value = $node->_set_node_ref_attribute__do_when_no_id_match( $attr_name, $attr_value );
			# Since we got here, $attr_value contains a positive search result.
			# Try calling superclass method again with new value.
			return( $node->SUPER::set_node_ref_attribute( $attr_name, $attr_value ) );
		}
		die $exception; # We can't do anything with this type of exception, so re-throw it.
	}
	return( 1 ); # The superclass was able to handle the input without error.
}

sub _set_node_ref_attribute__do_when_no_id_match {
	# Method only gets called when $attr_value is valued and doesn't match an id or Node.
	my ($self, $attr_name, $attr_value) = @_;
	my $exp_node_type = $self->expected_node_ref_attribute_type( $attr_name );

	my $container = $self->get_container();
	my $node_type = $self->get_node_type();

	my $node_info_extras = $NODE_TYPES_EXTRA_DETAILS{$node_type};
	my $search_path = $node_info_extras->{'search_paths'}->{$attr_name};

	my $attr_value_out = undef;
	if( !$search_path ) {
		# No specific search path given, so search all nodes of the type.
		$attr_value_out = $self->_find_node_by_link_search_attr( $exp_node_type, $attr_value );
	} elsif( $attr_value ) { # note: attr_value may be a defined empty string
		unless( $self->get_parent_node() ) {
			# Note: due to the above sorting, any attrs which could have set the 
			# parent would be evaluated before ...no_id_match called for first time.
			# We auto-set the parent here, earlier than create_node() would have, 
			# so that the current unresolved attr can use it in its search path.
			$container->_create_node_tree__do_when_parent_not_set( $self );
		}
		my $curr_node = $self;
		$attr_value_out = $self->_search_for_node( 
			$attr_value, $exp_node_type, $search_path, $curr_node );
	}

	if( $attr_value_out ) {
		return( $attr_value_out );
	} else {
		$self->_throw_error_message( 'SSMSID_N_SET_NREF_AT_NO_ID_MATCH', 
			{ 'ATNM' => $attr_name, 'HOSTTYPE' => $node_type, 
			'ARG' => $attr_value, 'EXPTYPE' => $exp_node_type } );
	}
}

sub _find_node_by_link_search_attr {
	my ($self, $exp_node_type, $attr_value) = @_;
	my $container = $self->get_container();
	my $link_search_attr = $NODE_TYPES_EXTRA_DETAILS{$exp_node_type}->{'link_search_attr'};
	foreach my $scn (values %{$container->{$CPROP_ALL_NODES}->{$exp_node_type}}) {
		if( $scn->get_attribute( $link_search_attr ) eq $attr_value ) {
			return( $scn );
		}
	}
}

sub _search_for_node {
	my ($self, $search_attr_value, $exp_node_type, $search_path, $curr_node) = @_;

	my $recurse_next = undef;

	foreach my $path_seg (@{$search_path}) {
		if( ref($path_seg) eq 'ARRAY' ) {
			# We have arrived at the parent of a possible desired node, but picking 
			# the correct child is more complicated, and will be done below.
			$recurse_next = $path_seg;
			last;
		} elsif( $path_seg eq $S ) {
			# Want to progress search via consec parents of same node type to first.
			my $start_type = $curr_node->get_node_type();
			while( $curr_node->get_parent_node() and $start_type eq
					$curr_node->get_parent_node()->get_node_type() ) {
				$curr_node = $curr_node->get_parent_node();
			}
		} elsif( $path_seg eq $P ) {
			# Want to progress search to the parent of the current node.
			if( $curr_node->get_parent_node() ) {
				# There is a parent node, so move to it.
				$curr_node = $curr_node->get_parent_node();
			} else {
				# There is no parent node; search has failed.
				$curr_node = undef;
				last;
			}
		} elsif( $path_seg eq $HACK1 ) {
			# Assume curr_node is now a 'view_rowset'; we want to find a view_src_col below it.
			# search_attr_value should be an array having 2 elements: view_src.name+table_col.name.
			# Progress search down one child node, so curr_node becomes a 'view_src'.
			my $to_be_curr_node = undef;
			my ($col_name, $src_name) = @{$search_attr_value};
			foreach my $scn (@{$curr_node->get_child_nodes( 'view_src' )}) {
				if( $scn->get_attribute( 'name' ) eq $src_name ) {
					# We found a node in the correct path that we can link.
					$to_be_curr_node = $scn;
					$search_attr_value = $col_name;
					last;
				}
			}
			$curr_node = $to_be_curr_node;
		} else {
			# Want to progress search via an attribute of the current node.
			if( my $attval = $curr_node->get_attribute( $path_seg ) ) {
				# The current node has that attribute, so move to it.
				$curr_node = $attval;
			} else {
				# There is no attribute present; search has failed.
				$curr_node = undef;
				last;
			}
		}
	}

	my $node_to_link = undef;

	if( $curr_node ) {
		# Since curr_node is still defined, the search succeeded, 
		# or the search path was an empty list (means search self).
		my $link_search_attr = $NODE_TYPES_EXTRA_DETAILS{$exp_node_type}->{'link_search_attr'};
		foreach my $scn (@{$curr_node->get_child_nodes( $exp_node_type )}) {
			if( $recurse_next ) {
				my ($i_exp_node_type, $i_search_path) = @{$recurse_next};
				my $i_node_to_link = undef;
				$i_node_to_link = $self->_search_for_node( 
					$search_attr_value, $i_exp_node_type, $i_search_path, $scn );

				if( $i_node_to_link ) {
					if( $scn->get_attribute( $link_search_attr ) eq $i_node_to_link ) {
						$node_to_link = $scn;
						last;
					}
				}
			} else {
				if( $scn->get_attribute( $link_search_attr ) eq $search_attr_value ) {
					# We found a node in the correct path that we can link.
					$node_to_link = $scn;
					last;
				}
			}
		}
	}

	return( $node_to_link );
}

######################################################################

sub set_attributes {
	my ($node, $attrs) = @_;
	defined( $attrs ) or $attrs = {};

	my $node_type = $node->get_node_type();
	my $node_info_extras = $NODE_TYPES_EXTRA_DETAILS{$node_type};

	unless( ref($attrs) eq 'HASH' ) {
		my $def_attr = $node_info_extras->{'def_attr'};
		unless( $def_attr ) {
			$node->_throw_error_message( 'SSMSID_N_SET_ATS_BAD_ARGS', 
				{ 'ARG' => $attrs, 'HOSTTYPE' => $node_type } );
		}
		$attrs = { $def_attr => $attrs };
	}

	my $attr_defaults = $node_info_extras && $node_info_extras->{'attr_defaults'};
	# This is placed here so that default strs can be processed into nodes below.
	if( $attr_defaults ) {
		my $container = $node->get_container();
		foreach my $attr_name (keys %{$attr_defaults}) {
			unless( defined( $node->get_attribute( $attr_name ) ) ) {
				unless( exists( $attrs->{$attr_name} ) ) {
					my ($def_type,$arg) = @{$attr_defaults->{$attr_name}};
					if( $def_type eq 'last' ) {
						# This 'last' feature, currently, should only be used with attributes that can not 
						# be primary parent attributes; pp attributes are sort of taken care 
						# of in _create_node_tree__do_when_parent_not_set(); 
						# however, that method's functionality may be moved here in the future
						my $exp_node_type = $node->valid_node_type_node_ref_attributes( $node_type, $attr_name );
						if( my $last_node = $container->{$CPROP_LAST_NODES}->{$exp_node_type} ) {
							$attrs->{$attr_name} = $last_node;
						}
					} else { # $def_type eq 'lit'
						$attrs->{$attr_name} = $arg;
					}
				}
			}
		}
	}

	# Here we isolate and set any input-provided Node ID or possible parent refs first
	if( my $new_node_id = delete( $attrs->{$ATTR_ID} ) ) {
		$node->set_node_id( $new_node_id );
	}
	my $valid_p_node_atnms = $node->valid_node_type_parent_attribute_names( $node_type );
	foreach my $attr_name (@{$valid_p_node_atnms}) {
		my $attr_value = delete( $attrs->{$attr_name} ) or next;
		$node->set_node_ref_attribute( $attr_name, $attr_value );
	}

	# Here we set any attributes not set by the previous code block
	$node->SUPER::set_attributes( $attrs );
}

######################################################################

sub create_child_node_tree {
	my ($node, $args) = @_;
	defined( $args ) or $node->_throw_error_message( 'SSMSID_N_CR_NODE_TREE_NO_ARGS' ); # same er as p

	unless( ref( $args ) eq 'HASH' ) {
		$args = { $ARG_NODE_TYPE => $args };
	}

	my $new_child = $node->new_node( $args->{$ARG_NODE_TYPE} );

	my $child_node_type = $new_child->get_node_type();

	my $container = $node->get_container();

	$new_child->get_node_id() or 
		$new_child->set_node_id( $container->get_next_free_node_id( $child_node_type ) );

	$new_child->put_in_container( $container );
	$new_child->add_reciprocal_links();

	$node->add_child_node( $new_child ); # sets more attributes in new_child

	$new_child->set_attributes( $args->{$ARG_ATTRS} ); # handles node id and all attribute types
	$new_child->test_deferrable_constraints();

	$container->{$CPROP_LAST_NODES}->{$child_node_type} = $new_child; # assign reference

	$new_child->create_child_node_trees( $args->{$ARG_CHILDREN} );

	return( $new_child );
}

sub create_child_node_trees {
	my ($node, $list) = @_;
	$list or return( undef );
	unless( ref($list) eq 'ARRAY' ) {
		$list = [ $list ];
	}
	foreach my $element (@{$list}) {
		if( ref($element) eq ref($node) ) {
			$node->add_child_node( $element ); # will die if not same Container
		} else {
			$node->create_child_node_tree( $element );
		}
	}
}

######################################################################
######################################################################

1;
__END__

=head1 SYNOPSIS

See the code inside the test script/module files that come with this module,
't/SQL_SyntaxModel_SkipID.t' and 'lib/t_SQL_SyntaxModel_SkipID.pm'.  That code
demonstrates input that can be provided to SQL::SyntaxModel::SkipID, along with
a way to debug the result; it is a contrived example since the class normally
wouldn't get used this way.  Such samples will not be shown in this POD to save
on redundancy.

=head1 DESCRIPTION

The SQL::SyntaxModel::SkipID Perl 5 module is a completely optional extension
to SQL::SyntaxModel, and is implemented as a sub-class of that module.  This 
module implements two distinct sets of additional features.

=head2 The First Set of Additional Features

This module adds a set of 4 new public methods which you can use to make some
tasks involving SQL::SyntaxModel less labour-intensive, depending on how you
like to use the module.

Using them, you can create a Node, set all of its attributes, put it in a
Container, and likewise recursively create all of its child Nodes, all with a
single method call.  In the context of this module, the set of Nodes consisting
of one starting Node and all of its "descendants" is called a "tree".  You can
create a tree of Nodes in mainly two contexts; one context will assign the
starting Node of the new tree as a child of an already existing Node; the other
will not explicitly attach the tree to an existing Node.

All of the added methods are wrappers over existing parent class methods, and
this module does not define any new class properties that are used by them.

=head2 The Second Set of Additional Features

The public interface to this module is essentially the same as its parent, with
the difference being that SQL::SyntaxModel::SkipID will accept a wider variety
of input data formats into its methods.  Therefore, this module's documentation
does not list or explain its methods (see the parent class for that), but it
will mention any differences from the parent.

The extension is intended to be fully parent-compatible, meaning that if you
provide it input which would be acceptable to the stricter bare parent class,
then you will get the same behaviour.  Where you will see the difference is
when you provide certain kinds of input which would cause the parent class to
return an error and/or throw an exception.

One significant added feature, which is part of this module's name-sake, is
that it will automatically generate (by serial number) a new Node's "id"
attribute when your input doesn't provide one.  A related name-sake feature is
that, when you want to refer to an earlier created Node by a later one, for
purposes of linking them, you can refer to the earlier Node by a more
human-readable attribute than the Node's "id" (or Node ref), such as its 'name'
(which is also what actual SQL uses).  Between these two name-sake features, it
is possible to use SQL::SyntaxModel::SkipID without ever having to explicitly
see a Node's "id" attribute.

Note that, for the sake of avoiding conflicts, you should not be explicitly
setting ids for some Nodes of a type, and having others auto-generated, unless
you take extra precautions.  This is because while auto-generated Node ids will
not conflict with prior explicit ones, later provided explicit ones may
conflict with auto-generated ones.  How you can resolve this is to use the
parent class' get_node() method to see if the id you want is already in use.
The same caveats apply as if the auto-generator was a second concurrent user
editing the object.  This said, you can mix references from one Node to another
between id and non-id ref types without further consequence, because they don't
change the id of a Node.

Another added feature is that this class can automatically assign a parent Node
for a newly created Node that doesn't explicitly specify a parent in some way,
such as in a create_node() argument or by the fact you are calling
add_child_node().  This automatic assignment is context-sensitive, whereby the
most recent previously-created Node which is capable of becoming the new one's
parent will do so.

This module's added features can make it "easier to use" in some circumstances
than the bare-bones SQL::SyntaxModel::SkipID, including an appearance more like
actual SQL strings, because matching descriptive terms can be used in multiple
places.

However, the functionality has its added cost in code complexity and
reliability; for example, since non-id attributes are not unique, the module
can "guess wrong" about what you wanted to do, and it won't work at all in some
circumstances.  Additionally, since your code, by using this module, would use
descriptive attributes to link Nodes together, you will have to update every
place you use the attribute value when you change the original, so they
continue to match; this is unlike the bare parent class, which always uses
non-descriptive attributes for links, which you are unlikely to ever change.
The added logic also makes the code slower and use more memory.

=head1 CONTAINER OBJECT METHODS

=head2 create_node_tree( { NODE_TYPE[, ATTRS][, CHILDREN] } )

	my $node = $model->create_node_tree( 
		{ 'NODE_TYPE' => 'catalog', 'ATTRS' => { 'id' => 1, } } ); 

This "setter" method creates a new Node object within the context of the
current Container and returns it.  It takes a hash ref containing up to 3 named
arguments: NODE_TYPE, ATTRS, CHILDREN.  The first argument, NODE_TYPE, is a
string (enum) which specifies the Node Type of the new Node.  The second
(optional) argument, ATTRS, is a hash ref whose elements will go in the various
"attributes" properties of the new Node (and the "node id" property if
applicable).  Any attributes which will refer to another Node can be passed in
as either a Node object reference or an integer which matches the 'id'
attribute of an already created Node.  The third (optional) argument, CHILDREN,
is an array ref whose elements will also be recursively made into new Nodes,
for which their primary parent is the Node you have just made here.  Elements
in CHILDREN are always processed after the other arguments. If the root Node
you are about to make should have a primary parent Node, then you would be
better to use said parent's create_child_node_tree[/s] method instead of this
one.  This method is actually a "wrapper" for a set of other, simpler
function/method calls that you could call directly instead if you wanted more
control over the process.

=head2 create_node_trees( LIST )

	$model->create_nodes( [{ ... }, { ... }] );
	$model->create_nodes( { ... } );

This "setter" method takes an array ref in its single LIST argument, and calls
create_node_tree() for each element found in it.

=head1 NODE OBJECT METHODS

=head2 create_child_node_tree( { NODE_TYPE[, ATTRS][, CHILDREN] } )

	my $new_child = $node->add_child_node( 
		{ 'NODE_TYPE' => 'schema', 'ATTRS' => { 'id' => 1, } } ); 

This "setter" method will create a new Node, following the same semantics (and
taking the same arguments) as the Container->create_node_tree(), except that 
create_child_node_tree() will also set the primary parent of the new Node to 
be the current Node.  This method also returns the new child Node.

=head2 create_child_node_trees( LIST )

	$model->create_child_node_tree( [$child1,$child2] );
	$model->create_child_node_tree( $child );

This "setter" method takes an array ref in its single LIST argument, and calls
create_child_node_tree() for each element found in it.

=head1 BUGS

See the BUGS main documentation section of SQL::SyntaxModel since everything
said there applies to this module also.

The "use base ..." pragma doesn't seem to work properly (with Perl 5.6 at
least) when I want to inherit from multiple classes, with some required parent
class methods not being seen; I had to use the analagous "use vars @ISA; @ISA =
..." syntax instead.

The mechanisms for automatically linking nodes to each other, and particularly
for resolving parent-child node relationships, are under-developed (somewhat
hackish) at the moment and probably won't work properly in all situations.
However, they do work for the test script/module code.  This linking code may 
gradually be improved if there is a need.  

=head1 CAVEATS

See the CAVEATS main documentation section of SQL::SyntaxModel since everything
said there applies to this module also.

See the TODO file for an important message concerning the future of this module.

=head1 SEE ALSO

SQL::SyntaxModel::SkipID::L::en, SQL::SyntaxModel, and other items in its SEE
ALSO documentation; also SQL::SyntaxModel::ByTree.

=cut
