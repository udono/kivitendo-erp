package SL::Controller::CsvImport::Order;


use strict;

use List::MoreUtils qw(any);

use SL::Helper::Csv;
use SL::DB::Order;
use SL::DB::OrderItem;
use SL::DB::Part;
use SL::DB::PaymentTerm;
use SL::DB::Contact;
use SL::DB::Department;
use SL::DB::PriceFactor;
use SL::DB::Pricegroup;
use SL::DB::Project;
use SL::DB::Shipto;
use SL::DB::TaxZone;
use SL::TransNumber;

use parent qw(SL::Controller::CsvImport::BaseMulti);


use Rose::Object::MakeMethods::Generic
(
 'scalar --get_set_init' => [ qw(settings languages_by parts_by contacts_by departments_by projects_by ct_shiptos_by taxzones_by price_factors_by pricegroups_by) ],
);


sub init_class {
  my ($self) = @_;
  $self->class(['SL::DB::Order', 'SL::DB::OrderItem']);
}


sub init_settings {
  my ($self) = @_;

  return { map { ( $_ => $self->controller->profile->get($_) ) } qw(order_column item_column max_amount_diff) };
}


sub init_profile {
  my ($self) = @_;

  my $profile = $self->SUPER::init_profile;

  # SUPER::init_profile sets row_ident to the class name
  # overwrite it with the user specified settings
  foreach my $p (@{ $profile }) {
    if ($p->{row_ident} eq 'Order') {
      $p->{row_ident} = $self->settings->{'order_column'};
    }
    if ($p->{row_ident} eq 'OrderItem') {
      $p->{row_ident} = $self->settings->{'item_column'};
    }
  }

  foreach my $p (@{ $profile }) {
    my $prof = $p->{profile};
    if ($p->{row_ident} eq $self->settings->{'order_column'}) {
      # no need to handle
      delete @{$prof}{qw(delivery_customer_id delivery_vendor_id proforma quotation amount netamount)};
    }
    if ($p->{row_ident} eq $self->settings->{'item_column'}) {
      # no need to handle
      delete @{$prof}{qw(trans_id)};
    }
  }

  return $profile;
}


sub setup_displayable_columns {
  my ($self) = @_;

  $self->SUPER::setup_displayable_columns;

  $self->add_displayable_columns($self->settings->{'order_column'},
                                 { name => 'datatype',         description => $::locale->text('Zeilenkennung')                  },
                                 { name => 'closed',           description => $::locale->text('Closed')                         },
                                 { name => 'curr',             description => $::locale->text('Currency')                       },
                                 { name => 'cusordnumber',     description => $::locale->text('Customer Order Number')          },
                                 { name => 'delivered',        description => $::locale->text('Delivered')                      },
                                 { name => 'employee_id',      description => $::locale->text('Employee (database ID)')         },
                                 { name => 'intnotes',         description => $::locale->text('Internal Notes')                 },
                                 { name => 'marge_percent',    description => $::locale->text('Margepercent')                   },
                                 { name => 'marge_total',      description => $::locale->text('Margetotal')                     },
                                 { name => 'notes',            description => $::locale->text('Notes')                          },
                                 { name => 'ordnumber',        description => $::locale->text('Order Number')                   },
                                 { name => 'quonumber',        description => $::locale->text('Quotation Number')               },
                                 { name => 'reqdate',          description => $::locale->text('Reqdate')                        },
                                 { name => 'salesman_id',      description => $::locale->text('Salesman (database ID)')         },
                                 { name => 'shippingpoint',    description => $::locale->text('Shipping Point')                 },
                                 { name => 'shipvia',          description => $::locale->text('Ship via')                       },
                                 { name => 'transaction_description', description => $::locale->text('Transaction description') },
                                 { name => 'transdate',        description => $::locale->text('Order Date')                     },
                                 { name => 'verify_amount',    description => $::locale->text('Amount (for verification)')      },
                                 { name => 'verify_netamount', description => $::locale->text('Net amount (for verification)')  },
                                 { name => 'taxincluded',      description => $::locale->text('Tax Included')                   },
                                 { name => 'customer',         description => $::locale->text('Customer (name)')                },
                                 { name => 'customernumber',   description => $::locale->text('Customer Number')                },
                                 { name => 'customer_id',      description => $::locale->text('Customer (database ID)')         },
                                 { name => 'vendor',           description => $::locale->text('Vendor (name)')                  },
                                 { name => 'vendornumber',     description => $::locale->text('Vendor Number')                  },
                                 { name => 'vendor_id',        description => $::locale->text('Vendor (database ID)')           },
                                 { name => 'language_id',      description => $::locale->text('Language (database ID)')         },
                                 { name => 'language',         description => $::locale->text('Language (name)')                },
                                 { name => 'payment_id',       description => $::locale->text('Payment terms (database ID)')    },
                                 { name => 'payment',          description => $::locale->text('Payment terms (name)')           },
                                 { name => 'taxzone_id',       description => $::locale->text('Steuersatz (database ID')        },
                                 { name => 'taxzone',          description => $::locale->text('Steuersatz (description)')       },
                                 { name => 'cp_id',            description => $::locale->text('Contact Person (database ID)')   },
                                 { name => 'contact',          description => $::locale->text('Contact Person (name)')          },
                                 { name => 'department_id',    description => $::locale->text('Department (database ID)')       },
                                 { name => 'department',       description => $::locale->text('Department (description)')       },
                                 { name => 'globalproject_id', description => $::locale->text('Document Project (database ID)') },
                                 { name => 'globalprojectnumber', description => $::locale->text('Document Project (number)')   },
                                 { name => 'globalproject',    description => $::locale->text('Document Project (description)') },
                                 { name => 'shipto_id',        description => $::locale->text('Ship to (database ID)')          },
                                );

  $self->add_displayable_columns($self->settings->{'item_column'},
                                 { name => 'datatype',        description => $::locale->text('Zeilenkennung')              },
                                 { name => 'cusordnumber',    description => $::locale->text('Customer Order Number')      },
                                 { name => 'description',     description => $::locale->text('Description')                },
                                 { name => 'discount',        description => $::locale->text('Discount')                   },
                                 { name => 'lastcost',        description => $::locale->text('Lastcost')                   },
                                 { name => 'longdescription', description => $::locale->text('Long Description')           },
                                 { name => 'marge_percent',   description => $::locale->text('Margepercent')               },
                                 { name => 'marge_total',     description => $::locale->text('Margetotal')                 },
                                 { name => 'ordnumber',       description => $::locale->text('Order Number')               },
                                 { name => 'parts_id',        description => $::locale->text('Part (database ID)')         },
                                 { name => 'partnumber',      description => $::locale->text('Part Number')                },
                                 { name => 'project_id',      description => $::locale->text('Project (database ID)')      },
                                 { name => 'projectnumber',   description => $::locale->text('Project (number)')           },
                                 { name => 'project',         description => $::locale->text('Project (description)')      },
                                 { name => 'price_factor_id', description => $::locale->text('Price factor (database ID)') },
                                 { name => 'price_factor',    description => $::locale->text('Price factor (name)')        },
                                 { name => 'pricegroup_id',   description => $::locale->text('Price group (database ID)')  },
                                 { name => 'pricegroup',      description => $::locale->text('Price group (name)')         },
                                 { name => 'qty',             description => $::locale->text('Quantity')                   },
                                 { name => 'reqdate',         description => $::locale->text('Reqdate')                    },
                                 { name => 'sellprice',       description => $::locale->text('Sellprice')                  },
                                 { name => 'serialnumber',    description => $::locale->text('Serial No.')                 },
                                 { name => 'subtotal',        description => $::locale->text('Subtotal')                   },
                                 { name => 'unit',            description => $::locale->text('Unit')                       },
                                );
}


sub init_languages_by {
  my ($self) = @_;

  return { map { my $col = $_; ( $col => { map { ( $_->$col => $_ ) } @{ $self->all_languages } } ) } qw(id description article_code) };
}

sub init_parts_by {
  my ($self) = @_;

  my $all_parts = SL::DB::Manager::Part->get_all;
  return { map { my $col = $_; ( $col => { map { ( $_->$col => $_ ) } @{ $all_parts } } ) } qw(id partnumber ean description) };
}

sub init_contacts_by {
  my ($self) = @_;

  my $all_contacts = SL::DB::Manager::Contact->get_all;

  my $cby;
  # by customer/vendor id  _and_  contact person id
  $cby->{'cp_cv_id+cp_id'}   = { map { ( $_->cp_cv_id . '+' . $_->cp_id   => $_ ) } @{ $all_contacts } };
  # by customer/vendor id  _and_  contact person name
  $cby->{'cp_cv_id+cp_name'} = { map { ( $_->cp_cv_id . '+' . $_->cp_name => $_ ) } @{ $all_contacts } };

  return $cby;
}

sub init_departments_by {
  my ($self) = @_;

  my $all_departments = SL::DB::Manager::Department->get_all;
  return { map { my $col = $_; ( $col => { map { ( $_->$col => $_ ) } @{ $all_departments } } ) } qw(id description) };
}

sub init_projects_by {
  my ($self) = @_;

  my $all_projects = SL::DB::Manager::Project->get_all;
  return { map { my $col = $_; ( $col => { map { ( $_->$col => $_ ) } @{ $all_projects } } ) } qw(id projectnumber description) };
}

sub init_ct_shiptos_by {
  my ($self) = @_;

  my $all_ct_shiptos = SL::DB::Manager::Shipto->get_all(query => [module => 'CT']);

  my $sby;
  # by trans_id  _and_  shipto_id
  $sby->{'trans_id+shipto_id'} = { map { ( $_->trans_id . '+' . $_->shipto_id => $_ ) } @{ $all_ct_shiptos } };

  return $sby;
}

sub init_taxzones_by {
  my ($self) = @_;

  my $all_taxzones = SL::DB::Manager::TaxZone->get_all;
  return { map { my $col = $_; ( $col => { map { ( $_->$col => $_ ) } @{ $all_taxzones } } ) } qw(id description) };
}

sub init_price_factors_by {
  my ($self) = @_;

  my $all_price_factors = SL::DB::Manager::PriceFactor->get_all;
  return { map { my $col = $_; ( $col => { map { ( $_->$col => $_ ) } @{ $all_price_factors } } ) } qw(id description) };
}

sub init_pricegroups_by {
  my ($self) = @_;

  my $all_pricegroups = SL::DB::Manager::Pricegroup->get_all;
  return { map { my $col = $_; ( $col => { map { ( $_->$col => $_ ) } @{ $all_pricegroups } } ) } qw(id pricegroup) };
}

sub check_objects {
  my ($self) = @_;

  $self->controller->track_progress(phase => 'building data', progress => 0);

  my $i;
  my $num_data = scalar @{ $self->controller->data };
  foreach my $entry (@{ $self->controller->data }) {
    $self->controller->track_progress(progress => $i/$num_data * 100) if $i % 100 == 0;

    if ($entry->{raw_data}->{datatype} eq $self->settings->{'order_column'}) {

      my $vc_obj;
      if (any { $entry->{raw_data}->{$_} } qw(customer customernumber customer_id)) {
        $self->check_vc($entry, 'customer_id');
        $vc_obj = SL::DB::Customer->new(id => $entry->{object}->customer_id)->load if $entry->{object}->customer_id;
      } elsif (any { $entry->{raw_data}->{$_} } qw(vendor vendornumber vendor_id)) {
        $self->check_vc($entry, 'vendor_id');
        $vc_obj = SL::DB::Vendor->new(id => $entry->{object}->vendor_id)->load if $entry->{object}->vendor_id;
      } else {
        push @{ $entry->{errors} }, $::locale->text('Error: Customer/vendor missing');
      }

      $self->check_contact($entry);
      $self->check_language($entry);
      $self->check_payment($entry);
      $self->check_department($entry);
      $self->check_project($entry, global => 1);
      $self->check_ct_shipto($entry);
      $self->check_taxzone($entry);

      if ($vc_obj) {
        # copy from customer if not given
        foreach (qw(payment_id language_id taxzone_id)) {
          $entry->{object}->$_($vc_obj->$_) unless $entry->{object}->$_;
        }
      }

      # ToDo: salesman and emloyee by name
      # salesman from customer or login if not given
      if (!$entry->{object}->salesman) {
        if ($vc_obj && $vc_obj->salesman_id) {
          $entry->{object}->salesman(SL::DB::Manager::Employee->find_by(id => $vc_obj->salesman_id));
        } else {
          $entry->{object}->salesman(SL::DB::Manager::Employee->find_by(login => $::myconfig{login}));
        }
      }

      # employee from login if not given
      if (!$entry->{object}->employee_id) {
        $entry->{object}->employee_id(SL::DB::Manager::Employee->find_by(login => $::myconfig{login})->id);
      }

    }
  }

  $self->add_info_columns($self->settings->{'order_column'},
                          { header => $::locale->text('Customer/Vendor'), method => 'vc_name' });
  # Todo: access via ->[0] ok? Better: search first order column and use this
  $self->add_columns($self->settings->{'order_column'},
                     map { "${_}_id" } grep { exists $self->controller->data->[0]->{raw_data}->{$_} } qw(payment language department globalproject taxzone cp));
  $self->add_columns($self->settings->{'order_column'}, 'globalproject_id') if exists $self->controller->data->[0]->{raw_data}->{globalprojectnumber};
  $self->add_columns($self->settings->{'order_column'}, 'cp_id')            if exists $self->controller->data->[0]->{raw_data}->{contact};

  foreach my $entry (@{ $self->controller->data }) {
    if ($entry->{raw_data}->{datatype} eq $self->settings->{'item_column'} && $entry->{object}->can('part')) {

      next if !$self->check_part($entry);

      my $part_obj = SL::DB::Part->new(id => $entry->{object}->parts_id)->load;

      # copy from part if not given
      $entry->{object}->description($part_obj->description) unless $entry->{object}->description;
      $entry->{object}->longdescription($part_obj->notes)   unless $entry->{object}->longdescription;
      $entry->{object}->unit($part_obj->unit)               unless $entry->{object}->unit;

      # set to 0 if not given
      $entry->{object}->discount(0)      unless $entry->{object}->discount;
      $entry->{object}->ship(0)          unless $entry->{object}->ship;

      $self->check_project($entry, global => 0);
      $self->check_price_factor($entry);
      $self->check_pricegroup($entry);
    }
  }

  $self->add_info_columns($self->settings->{'item_column'},
                          { header => $::locale->text('Part Number'), method => 'partnumber' });
  # Todo: access via ->[1] ok? Better: search first item column and use this
  $self->add_columns($self->settings->{'item_column'},
                     map { "${_}_id" } grep { exists $self->controller->data->[1]->{raw_data}->{$_} } qw(project price_factor pricegroup));
  $self->add_columns($self->settings->{'item_column'}, 'project_id') if exists $self->controller->data->[1]->{raw_data}->{projectnumber};

  # add orderitems to order
  my $order_entry;
  my @orderitems;
  foreach my $entry (@{ $self->controller->data }) {
    # search first Order
    if ($entry->{raw_data}->{datatype} eq $self->settings->{'order_column'}) {

      # new order entry: add collected orderitems to the last one
      if (defined $order_entry) {
        $order_entry->{object}->orderitems(@orderitems);
        @orderitems = ();
      }

      $order_entry = $entry;

    } elsif ( defined $order_entry && $entry->{raw_data}->{datatype} eq $self->settings->{'item_column'} ) {
      # collect orderitems to add to order (if they have no errors)
      # ( add_orderitems does not work here if we want to call
      #   calculate_prices_and_taxes afterwards ...
      #   so collect orderitems and add them at once)
      if (scalar @{ $entry->{errors} } == 0) {
        push @orderitems, $entry->{object};
      }
    }
  }
  # add last collected orderitems to last order
  if ($order_entry) {
    $order_entry->{object}->orderitems(@orderitems);
  }

  # calculate prices and taxes
  foreach my $entry (@{ $self->controller->data }) {
    next if @{ $entry->{errors} };

    if ($entry->{raw_data}->{datatype} eq $self->settings->{'order_column'}) {

      $entry->{object}->calculate_prices_and_taxes;

      $entry->{info_data}->{calc_amount}    = $entry->{object}->amount_as_number;
      $entry->{info_data}->{calc_netamount} = $entry->{object}->netamount_as_number;
    }
  }

  # If amounts are given, show calculated amounts as info and given amounts (verify_xxx).
  # And throw an error if the differences are too big.
  my @to_verify = ( { column      => 'amount',
                      raw_column  => 'verify_amount',
                      info_header => 'Calc. Amount',
                      info_method => 'calc_amount',
                      err_msg     => 'Amounts differ too much',
                    },
                    { column      => 'netamount',
                      raw_column  => 'verify_netamount',
                      info_header => 'Calc. Net amount',
                      info_method => 'calc_netamount',
                      err_msg     => 'Net amounts differ too much',
                    } );

  foreach my $tv (@to_verify) {
    # Todo: access via ->[0] ok? Better: search first order column and use this
    if (exists $self->controller->data->[0]->{raw_data}->{ $tv->{raw_column} }) {
      $self->add_raw_data_columns($self->settings->{'order_column'}, $tv->{raw_column});
      $self->add_info_columns($self->settings->{'order_column'},
                              { header => $::locale->text($tv->{info_header}), method => $tv->{info_method} });
    }

    # check differences
    foreach my $entry (@{ $self->controller->data }) {
      next if @{ $entry->{errors} };
      if ($entry->{raw_data}->{datatype} eq $self->settings->{'order_column'}) {
        next if !$entry->{raw_data}->{ $tv->{raw_column} };
        my $parsed_value = $::form->parse_amount(\%::myconfig, $entry->{raw_data}->{ $tv->{raw_column} });
        if (abs($entry->{object}->${ \$tv->{column} } - $parsed_value) > $self->settings->{'max_amount_diff'}) {
          push @{ $entry->{errors} }, $::locale->text($tv->{err_msg});
        }
      }
    }
  }

  # If order has errors set error for orderitems as well
  my $order_entry;
  foreach my $entry (@{ $self->controller->data }) {
    # Search first order
    if ($entry->{raw_data}->{datatype} eq $self->settings->{'order_column'}) {
      $order_entry = $entry;
    } elsif ( defined $order_entry
              && $entry->{raw_data}->{datatype} eq $self->settings->{'item_column'}
              && scalar @{ $order_entry->{errors} } > 0 ) {
      push @{ $entry->{errors} }, $::locale->text('order not valid for this orderitem!');
    }
  }

}


sub check_language {
  my ($self, $entry) = @_;

  my $object = $entry->{object};

  # Check whether or not language ID is valid.
  if ($object->language_id && !$self->languages_by->{id}->{ $object->language_id }) {
    push @{ $entry->{errors} }, $::locale->text('Error: Invalid language');
    return 0;
  }

  # Map name to ID if given.
  if (!$object->language_id && $entry->{raw_data}->{language}) {
    my $language = $self->languages_by->{description}->{  $entry->{raw_data}->{language} }
                || $self->languages_by->{article_code}->{ $entry->{raw_data}->{language} };

    if (!$language) {
      push @{ $entry->{errors} }, $::locale->text('Error: Invalid language');
      return 0;
    }

    $object->language_id($language->id);
  }

  if ($object->language_id) {
    $entry->{info_data}->{language} = $self->languages_by->{id}->{ $object->language_id }->description;
  }

  return 1;
}

sub check_part {
  my ($self, $entry) = @_;

  my $object = $entry->{object};

  # Check wether or non part ID is valid.
  if ($object->parts_id && !$self->parts_by->{id}->{ $object->parts_id }) {
    push @{ $entry->{errors} }, $::locale->text('Error: Invalid part');
    return 0;
  }

  # Map number to ID if given.
  if (!$object->parts_id && $entry->{raw_data}->{partnumber}) {
    my $part = $self->parts_by->{partnumber}->{ $entry->{raw_data}->{partnumber} };
    if (!$part) {
      push @{ $entry->{errors} }, $::locale->text('Error: Invalid part');
      return 0;
    }

    $object->parts_id($part->id);
  }

  if ($object->parts_id) {
    $entry->{info_data}->{partnumber} = $self->parts_by->{id}->{ $object->parts_id }->partnumber;
  } else {
    push @{ $entry->{errors} }, $::locale->text('Error: Part not found');
    return 0;
  }

  return 1;
}

sub check_contact {
  my ($self, $entry) = @_;

  my $object = $entry->{object};

  my $cp_cv_id = $object->customer_id || $object->vendor_id;
  return 0 unless $cp_cv_id;

  # Check wether or not contact ID is valid.
  if ($object->cp_id && !$self->contacts_by->{'cp_cv_id+cp_id'}->{ $cp_cv_id . '+' . $object->cp_id }) {
    push @{ $entry->{errors} }, $::locale->text('Error: Invalid contact');
    return 0;
  }

  # Map name to ID if given.
  if (!$object->cp_id && $entry->{raw_data}->{contact}) {
    my $cp = $self->contacts_by->{'cp_cv_id+cp_name'}->{ $cp_cv_id . '+' . $entry->{raw_data}->{contact} };
    if (!$cp) {
      push @{ $entry->{errors} }, $::locale->text('Error: Invalid contact');
      return 0;
    }

    $object->cp_id($cp->cp_id);
  }

  if ($object->cp_id) {
    $entry->{info_data}->{contact} = $self->contacts_by->{'cp_cv_id+cp_id'}->{ $cp_cv_id . '+' . $object->cp_id }->cp_name;
  }

  return 1;
}

sub check_department {
  my ($self, $entry) = @_;

  my $object = $entry->{object};

  # Check wether or not department ID is valid.
  if ($object->department_id && !$self->departments_by->{id}->{ $object->department_id }) {
    push @{ $entry->{errors} }, $::locale->text('Error: Invalid department');
    return 0;
  }

  # Map description to ID if given.
  if (!$object->department_id && $entry->{raw_data}->{department}) {
    my $dep = $self->departments_by->{description}->{ $entry->{raw_data}->{department} };
    if (!$dep) {
      push @{ $entry->{errors} }, $::locale->text('Error: Invalid department');
      return 0;
    }

    $object->department_id($dep->id);
  }

  return 1;
}

sub check_project {
  my ($self, $entry, %params) = @_;

  my $id_column          = ($params{global} ? 'global' : '') . 'project_id';
  my $number_column      = ($params{global} ? 'global' : '') . 'projectnumber';
  my $description_column = ($params{global} ? 'global' : '') . 'project';

  my $object = $entry->{object};

  # Check wether or not projetc ID is valid.
  if ($object->$id_column && !$self->projects_by->{id}->{ $object->$id_column }) {
    push @{ $entry->{errors} }, $::locale->text('Error: Invalid project');
    return 0;
  }

  # Map number to ID if given.
  if (!$object->$id_column && $entry->{raw_data}->{$number_column}) {
    my $proj = $self->projects_by->{projectnumber}->{ $entry->{raw_data}->{$number_column} };
    if (!$proj) {
      push @{ $entry->{errors} }, $::locale->text('Error: Invalid project');
      return 0;
    }

    $object->$id_column($proj->id);
  }

  # Map description to ID if given.
  if (!$object->$id_column && $entry->{raw_data}->{$description_column}) {
    my $proj = $self->projects_by->{description}->{ $entry->{raw_data}->{$description_column} };
    if (!$proj) {
      push @{ $entry->{errors} }, $::locale->text('Error: Invalid project');
      return 0;
    }

    $object->$id_column($proj->id);
  }

  return 1;
}

sub check_ct_shipto {
  my ($self, $entry) = @_;

  my $object = $entry->{object};

  my $trans_id = $object->customer_id || $object->vendor_id;
  return 0 unless $trans_id;

  # Check wether or not shipto ID is valid.
  if ($object->shipto_id && !$self->ct_shiptos_by->{'trans_id+shipto_id'}->{ $trans_id . '+' . $object->shipto_id }) {
    push @{ $entry->{errors} }, $::locale->text('Error: Invalid shipto');
    return 0;
  }

  return 1;
}

sub check_taxzone {
  my ($self, $entry) = @_;

  my $object = $entry->{object};

  # Check wether or not taxzone ID is valid.
  if ($object->taxzone_id && !$self->taxzones_by->{id}->{ $object->taxzone_id }) {
    push @{ $entry->{errors} }, $::locale->text('Error: Invalid taxzone');
    return 0;
  }

  # Map description to ID if given.
  if (!$object->taxzone_id && $entry->{raw_data}->{taxzone}) {
    my $taxzone = $self->taxzones_by->{description}->{ $entry->{raw_data}->{taxzone} };
    if (!$taxzone) {
      push @{ $entry->{errors} }, $::locale->text('Error: Invalid taxzone');
      return 0;
    }

    $object->taxzone_id($taxzone->id);
  }

  return 1;
}


sub check_price_factor {
  my ($self, $entry) = @_;

  my $object = $entry->{object};

  # Check wether or not price_factor ID is valid.
  if ($object->price_factor_id && !$self->price_factors_by->{id}->{ $object->price_factor_id }) {
    push @{ $entry->{errors} }, $::locale->text('Error: Invalid price factor');
    return 0;
  }

  # Map description to ID if given.
  if (!$object->price_factor_id && $entry->{raw_data}->{price_factor}) {
    my $price_factor = $self->price_factors_by->{description}->{ $entry->{raw_data}->{price_factor} };
    if (!$price_factor) {
      push @{ $entry->{errors} }, $::locale->text('Error: Invalid price factor');
      return 0;
    }

    $object->price_factor_id($price_factor->id);
  }

  return 1;
}

sub check_pricegroup {
  my ($self, $entry) = @_;

  my $object = $entry->{object};

  # Check wether or not pricegroup ID is valid.
  if ($object->pricegroup_id && !$self->pricegroups_by->{id}->{ $object->pricegroup_id }) {
    push @{ $entry->{errors} }, $::locale->text('Error: Invalid price group');
    return 0;
  }

  # Map pricegroup to ID if given.
  if (!$object->pricegroup_id && $entry->{raw_data}->{pricegroup}) {
    my $pricegroup = $self->pricegroups_by->{pricegroup}->{ $entry->{raw_data}->{pricegroup} };
    if (!$pricegroup) {
      push @{ $entry->{errors} }, $::locale->text('Error: Invalid price group');
      return 0;
    }

    $object->pricegroup_id($pricegroup->id);
  }

  return 1;
}


sub save_objects {
  my ($self, %params) = @_;

  # set order number and collect to save
  my $objects_to_save;
  foreach my $entry (@{ $self->controller->data }) {
    next if @{ $entry->{errors} };

    if ($entry->{raw_data}->{datatype} eq $self->settings->{'order_column'} && !$entry->{object}->ordnumber) {
      my $number = SL::TransNumber->new(type        => 'sales_order',
                                        save        => 1);
      $entry->{object}->ordnumber($number->create_unique());
    }

    push @{ $objects_to_save }, $entry;
  }

  $self->SUPER::save_objects(data => $objects_to_save);
}


1;