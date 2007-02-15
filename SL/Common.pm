#====================================================================
# LX-Office ERP
# Copyright (C) 2004
# Based on SQL-Ledger Version 2.1.9
# Web http://www.lx-office.org
#
#====================================================================

package Common;

use Time::HiRes qw(gettimeofday);

sub unique_id {
  my ($a, $b) = gettimeofday();
  return "${a}-${b}-${$}";
}

sub tmpname {
  return "/tmp/lx-office-tmp-" . unique_id();
}

sub retrieve_parts {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form, $order_by, $order_dir) = @_;

  my $dbh = $form->dbconnect($myconfig);

  my (@filter_values, $filter);
  if ($form->{"partnumber"}) {
    $filter .= " AND (partnumber ILIKE ?)";
    push(@filter_values, '%' . $form->{"partnumber"} . '%');
  }
  if ($form->{"description"}) {
    $filter .= " AND (description ILIKE ?)";
    push(@filter_values, '%' . $form->{"description"} . '%');
  }
  substr($filter, 1, 3) = "WHERE" if ($filter);

  $order_by =~ s/[^a-zA-Z_]//g;
  $order_dir = $order_dir ? "ASC" : "DESC";

  my $query = "SELECT id, partnumber, description FROM parts $filter ORDER BY $order_by $order_dir";
  my $sth = $dbh->prepare($query);
  $sth->execute(@filter_values) || $form->dberror($query . " (" . join(", ", @filter_values) . ")");
  my $parts = [];
  while (my $ref = $sth->fetchrow_hashref()) {
    push(@{$parts}, $ref);
  }
  $sth->finish();
  $dbh->disconnect();

  $main::lxdebug->leave_sub();

  return $parts;
}

sub retrieve_projects {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form, $order_by, $order_dir) = @_;

  my $dbh = $form->dbconnect($myconfig);

  my (@filter_values, $filter);
  if ($form->{"projectnumber"}) {
    $filter .= " AND (projectnumber ILIKE ?)";
    push(@filter_values, '%' . $form->{"projectnumber"} . '%');
  }
  if ($form->{"description"}) {
    $filter .= " AND (description ILIKE ?)";
    push(@filter_values, '%' . $form->{"description"} . '%');
  }
  substr($filter, 1, 3) = "WHERE" if ($filter);

  $order_by =~ s/[^a-zA-Z_]//g;
  $order_dir = $order_dir ? "ASC" : "DESC";

  my $query = "SELECT id, projectnumber, description FROM project $filter ORDER BY $order_by $order_dir";
  my $sth = $dbh->prepare($query);
  $sth->execute(@filter_values) || $form->dberror($query . " (" . join(", ", @filter_values) . ")");
  my $projects = [];
  while (my $ref = $sth->fetchrow_hashref()) {
    push(@{$projects}, $ref);
  }
  $sth->finish();
  $dbh->disconnect();

  $main::lxdebug->leave_sub();

  return $projects;
}

sub retrieve_employees {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form, $order_by, $order_dir) = @_;

  my $dbh = $form->dbconnect($myconfig);

  my (@filter_values, $filter);
  if ($form->{"name"}) {
    $filter .= " AND (name ILIKE ?)";
    push(@filter_values, '%' . $form->{"name"} . '%');
  }
  substr($filter, 1, 3) = "WHERE" if ($filter);

  $order_by =~ s/[^a-zA-Z_]//g;
  $order_dir = $order_dir ? "ASC" : "DESC";

  my $query = "SELECT id, name FROM employee $filter ORDER BY $order_by $order_dir";
  my $sth = $dbh->prepare($query);
  $sth->execute(@filter_values) || $form->dberror($query . " (" . join(", ", @filter_values) . ")");
  my $employees = [];
  while (my $ref = $sth->fetchrow_hashref()) {
    push(@{$employees}, $ref);
  }
  $sth->finish();
  $dbh->disconnect();

  $main::lxdebug->leave_sub();

  return $employees;
}

sub retrieve_delivery_customer {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form, $order_by, $order_dir) = @_;

  my $dbh = $form->dbconnect($myconfig);

  my (@filter_values, $filter);
  if ($form->{"name"}) {
    $filter .= " (name ILIKE '%$form->{name}%') AND";
    push(@filter_values, '%' . $form->{"name"} . '%');
  }
  #substr($filter, 1, 3) = "WHERE" if ($filter);

  $order_by =~ s/[^a-zA-Z_]//g;
  $order_dir = $order_dir ? "ASC" : "DESC";

  my $query = "SELECT id, name, customernumber, (street || ', ' || zipcode || city) as address FROM customer WHERE $filter business_id=(SELECT id from business WHERE description='Endkunde') ORDER BY $order_by $order_dir";
  my $sth = $dbh->prepare($query);
  $sth->execute() || $form->dberror($query . " (" . join(", ", @filter_values) . ")");
  my $delivery_customers = [];
  while (my $ref = $sth->fetchrow_hashref()) {
    push(@{$delivery_customers}, $ref);
  }
  $sth->finish();
  $dbh->disconnect();

  $main::lxdebug->leave_sub();

  return $delivery_customers;
}

sub retrieve_vendor {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form, $order_by, $order_dir) = @_;

  my $dbh = $form->dbconnect($myconfig);

  my (@filter_values, $filter);
  if ($form->{"name"}) {
    $filter .= " (name ILIKE '%$form->{name}%') AND";
    push(@filter_values, '%' . $form->{"name"} . '%');
  }
  #substr($filter, 1, 3) = "WHERE" if ($filter);

  $order_by =~ s/[^a-zA-Z_]//g;
  $order_dir = $order_dir ? "ASC" : "DESC";

  my $query = "SELECT id, name, customernumber, (street || ', ' || zipcode || city) as address FROM customer WHERE $filter business_id=(SELECT id from business WHERE description='H�ndler') ORDER BY $order_by $order_dir";
  my $sth = $dbh->prepare($query);
  $sth->execute() || $form->dberror($query . " (" . join(", ", @filter_values) . ")");
  my $vendors = [];
  while (my $ref = $sth->fetchrow_hashref()) {
    push(@{$vendors}, $ref);
  }
  $sth->finish();
  $dbh->disconnect();

  $main::lxdebug->leave_sub();

  return $vendors;
}

sub mkdir_with_parents {
  $main::lxdebug->enter_sub();

  my ($full_path) = @_;

  my $path = "";

  $full_path =~ s|/+|/|;

  foreach my $part (split(m|/|, $full_path)) {
    $path .= "/" if ($path);
    $path .= $part;

    die("Could not create directory '$path' because a file exists with " .
        "the same name.\n") if (-f $path);

    if (! -d $path) {
      mkdir($path, 0770) || die("Could not create the directory '$path'. " .
                                "OS error: $!\n");
    }
  }

  $main::lxdebug->leave_sub();
}

sub webdav_folder {
  $main::lxdebug->enter_sub();

  my ($form) = @_;

  return $main::lxdebug->leave_sub()
    unless ($main::webdav && $form->{id});

  my ($path, $number);

  $form->{WEBDAV} = {};

  if ($form->{type} eq "sales_quotation") {
    ($path, $number) = ("angebote", $form->{quonumber});
  } elsif ($form->{type} eq "sales_order") {
    ($path, $number) = ("bestellungen", $form->{ordnumber});
  } elsif ($form->{type} eq "request_quotation") {
    ($path, $number) = ("anfragen", $form->{quonumber});
  } elsif ($form->{type} eq "purchase_order") {
    ($path, $number) = ("lieferantenbestellungen", $form->{ordnumber});
  } elsif ($form->{type} eq "credit_note") {
    ($path, $number) = ("gutschriften", $form->{invnumber});
  } elsif ($form->{vc} eq "customer") {
    ($path, $number) = ("rechnungen", $form->{invnumber});
  } else {
    ($path, $number) = ("einkaufsrechnungen", $form->{invnumber});
  }

  return $main::lxdebug->leave_sub() unless ($path && $number);

  $path = "webdav/${path}/${number}";

  if (!-d $path) {
    mkdir_with_parents($path);

  } else {
    my $base_path = substr($ENV{'SCRIPT_NAME'}, 1);
    $base_path =~ s|[^/]+$||;

    foreach my $file (<$path/*>) {
      my $fname = $file;
      $fname =~ s|.*/||;
      $form->{WEBDAV}{$fname} =
        ($ENV{"HTTPS"} ? "https://" : "http://") .
        $ENV{'SERVER_NAME'} . "/" . $base_path . $file;
    }
  }

  $main::lxdebug->leave_sub();
}

1;
