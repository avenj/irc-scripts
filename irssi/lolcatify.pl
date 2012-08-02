## lolcatify.pl
our $VERSION = '0.01';

## Need at least perl-5.10.1
use 5.10.1;
use strict; use warnings FATAL => 'all';

## Non-portable path. Alter as-needed.
my $SAVED_CATS_TO = $ENV{HOME} . ".irssi/saved_lulzcats" ;

## The Perl that irssi was built against will need this
## ( or just shove LOLCAT.pm in .irssi/scripts/Acme/ )
use Acme::LOLCAT qw//;

use Irssi        qw//;

our %IRSSI = (
  name => 'lolcatify',

  authors => 'Jon Portnoy',
  contact => 'avenj@cobaltirc.org',

  description => 'Turn a user into a lolcat',
  
  license => 'perl5',
);

## $lulzcats{ $mask } = time()
our %lulzcats;
restore_cats( $SAVED_CATS_TO )
  if -e $SAVED_CATS_TO;

Irssi::command_bind lolcat => sub {
  ## Dispatcher.
  my ($msg, $server, $win) = @_;

  my ($cmd, @params) = split ' ', $msg;

  my %disp = (
    help => \&lolcat_help,
    add  => \&lolcat_add,
    del  => \&lolcat_del,
    list => \&lolcat_list,
  );

  $cmd = lc( $cmd ||= 'list' );
  $cmd = 'help' unless defined $disp{$cmd};

  $disp{$cmd}->($server, $win, @params)
};

Irssi::signal_add "message public"  => \&incoming_msg;

## FIXME configurably add privmsg handler?
#Irssi::signal_add "message private" => \&incoming_msg;

sub incoming_msg {
  my ($serv, $msg, $nick, $addr, $target) = @_;

  MASK: for my $mask (keys %lulzcats) {
    if ( $serv->mask_match_address($mask, $nick, $addr) ) {
      Irssi::signal_continue(
        $serv,
        Acme::LOLCAT::translate($msg),
        $nick, $addr, $target
      );
    
      last MASK
    }
  }

};

sub lolcat_help {
  my ($server, $win, @params) = @_;

  my @help = (
    "Usage:",
    " lolcat help",
    " lolcat list",
    " lolcat add <mask>",
    " lolcat del <mask>",
  );

  print_cur(
    window => $win,
    lines  => \@help,
  );
}


sub lolcat_list {
  my ($server, $win, @params) = @_;

  unless (keys %lulzcats) {
    print_cur(
      window => $win,
      lines  => [ "I haz no lulzcats." ],
    );
  } else {
    my @output = ( "I haz cats:" );
    
    push( @output,
      " - " . $_
    ) for keys %lulzcats;
  
    print_cur(
      window => $win,
      lines  => \@output,
    );
  }
}

sub print_cur {
  my %args = @_;
  $args{lc $_} = delete $args{$_} for keys %args;

  return unless defined $args{lines}
    and ref $args{lines} eq 'ARRAY' ;
  
  if (ref $args{window}) {
    $args{window}->print($_) for @{ $args{lines} };
  } else {
    Irssi::print($_) for @{ $args{lines} };
  }
}

sub lolcat_add {
  my ($server, $win, @params) = @_;

  my ($mask) = @params;

  unless (defined $mask) {
    print_cur(
      window => $win,
      lines  => [ "I haz no cat to add!" ],
    );
    
    return
  }

  $mask = normalize_mask($mask);

  $lulzcats{ $mask } = time();

  print_cur(
    window => $win,
    lines  => [ "I now haz cat $mask" ],
  );

  save_cats( $SAVED_CATS_TO );
}

sub lolcat_del {
  my ($server, $win, @params) = @_;

  my ($mask) = @params;

  unless (defined $mask) {
    print_cur(
      window => $win,
      lines  => [ "I haz no cat to lose!" ],
    );
    
    return
  }
  
  if (delete $lulzcats{ $mask }) {
    print_cur(
      window => $win,
      lines  => [ "I no haz $mask nao." ],
    );
  } else {
    print_cur(
      window => $win,
      lines  => [ "I no can find cat $mask to delete!" ],
    );
  }
}

sub save_cats {
  my ($file) = @_;

  my @output;
  for my $mask (keys %lulzcats) {
    my $ts = $lulzcats{$mask};
    push( @output,
      "$mask $ts\n"
    );    
  }

  return unless @output;

  open my $fh, '>', $file
    or warn "Could not open $file to save lulzcats: $!"
    and return;

  print $fh @output;

  close $fh;

  1
}

sub restore_cats {
  my ($file) = @_;

  open my $fh, '<', $file
    or warn "Could not open $file to restore lulzcats: $!"
    and return;

  my @input = readline($fh);

  close $fh;

  for my $line (@input) {
    chomp $line;

    my ($mask, $ts) = split ' ', $line;

    $lulzcats{ $mask } = $ts;
  }
  
  1
}


sub normalize_mask {
  my ($orig) = @_;
  return unless defined $orig;

  ## Inlined with some tweaks from IRC::Utils

  ## **+ --> *
  $orig =~ s/\*{2,}/*/g;
  
  my @mask;
  my $piece;

  ## Push nick, if we have one, or * if we don't.
  if ( $orig !~ /!/ && $orig =~ /@/ ) {
    $piece = $orig;
    push(@mask, '*');
  } else {
    ($mask[0], $piece) = split /!/, $orig, 2;
  }

  ## Split user/host portions and do some clean up.
  $piece =~ s/!//g if defined $piece;
  @mask[1 .. 2] = split( /@/, $piece, 2) if defined $piece;
  $mask[2] =~ s/@//g if defined $mask[2];

  for ( 1 .. 2 ) {
    $mask[$_] = '*' unless defined $mask[$_];
  }

  $mask[0] . '!' . $mask[1] . '@' . $mask[2] 
}
