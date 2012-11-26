use strict; use warnings FATAL => 'all';
use Xchat;
use 5.12.1;
my $VERSION = '0.1';

require File::Spec;

my $save_path = get_save_location("colorified.cf")
  or die "Could not determine a safe save location";

my @reg = (
  'Channel Message',
  'Channel Action',
  'Channel Msg Hilight',
  'Channel Action Hilight',
#  'Your Message',
#  'Your Action',
);

my %nicks;
my %cl = qw/
  darkblue    18
  blue        28
  cyan        26
  brightcyan  27
  green       19
  brightgreen 25
  red         20
  darkred     21
  purple      22
  orange      23
  yellow      24
  magenta     29
  darkgray    30
  gray        31
  lightgray   16
/;

Xchat::register('ColorizeTxt', $VERSION, "Colorize text from users");

Xchat::print("o hai, colorizer thingo loaded");
Xchat::print($_) for (
  "-> Add via /colorify <nick> <color>",
  "-> Del via /decolorify <nick>",
  "-> List current via /colorify",
  "-> List colors via /colorify -colors",
);
Xchat::hook_print($_, \&colorify,
  {
    data     => $_,
    priority => Xchat::PRI_HIGH,
  },
) for @reg;

Xchat::hook_command( $_, \&cmd_colorify,
  {
    help_text => "Colorify/decolorify text from users",
  },
) for qw/colorify decolorify uncolorify/;

sub colorify {
  my $event = $_[1];

  my ($nick, $first) = @{ $_[0] };

  my $colorify = get_color_for(
    lc( $nick || return Xchat::EAT_NONE )
  );

  return Xchat::EAT_NONE
    if not defined $first
    or not $colorify
    or $first =~ /^\003/;

  my $last  = $_[0]->[-1];

  $_[0]->[1] = "\003" . $colorify . $first;
  $last .= "\003";

  Xchat::emit_print($event, @{ $_[0] });
  Xchat::EAT_ALL
}


sub get_color_for {
  my ($nick) = @_;

  %nicks = %{ load_colorified($save_path) }
    unless keys %nicks;
  my $named_c = $nicks{$nick} || return;

  unless ($cl{$named_c}) {
    Xchat::print("$nick has unknown color $named_c");
    return
  }

  $cl{$named_c}
}

sub cmd_colorify {
  my ($cmd, @args) = @{ $_[0] };

  my $nick = lc($args[0] || '');

  %nicks = %{ load_colorified($save_path) }
    unless keys %nicks;

  unless ($nick) {
    Xchat::print("Current colorifications:");
    Xchat::print("  $_")
      for map {; "$_ is $nicks{$_}" } keys %nicks;
    return Xchat::EAT_ALL
  }


  if ($nick eq '-colors') {
    Xchat::print("Available colors:");
    Xchat::print("  $_") for keys %cl;
    return Xchat::EAT_ALL
  }

  if ($cmd eq 'colorify') {
    my $color = lc($args[1] || '');

    unless ($color && $cl{$color}) {
      Xchat::print("No color specified or no such color.");
      return Xchat::EAT_ALL
    }

    $nicks{$nick} = $color;

    Xchat::print("coloring $nick");
    save_colorified($save_path, \%nicks);
  } elsif ($cmd eq 'decolorify' || $cmd eq 'uncolorify') {

    unless (delete $nicks{$nick}) {
      Xchat::print("Do not have colorified nick $nick");
      return Xchat::EAT_ALL
    }

    Xchat::print("decoloring $nick");
    save_colorified($save_path, \%nicks);
  } else {
    Xchat::print("what the fuck? fell through in cmd_colorify")
  }

  Xchat::EAT_ALL
}

sub get_save_location {
  my ($file) = @_;
  my $dir = Xchat::get_info('xchatdir')  ## X-Chat
    || Xchat::get_info('configdir');     ## HexChat

  unless ($dir) {
    warn "get_save_location could not determine a configdir";
    return
  }

  File::Spec->catfile($dir, $file)
}

sub save_colorified {
  my ($file, $ref) = @_;

  die "Expected file and ref" unless $file and ref $ref eq 'HASH';

  my @ln;
  while (my ($key,$val) = each %$ref) {
    push @ln, "$key $val\n";
  }
  return unless @ln;

  open my $fh, '>', $file
    or warn "Could not open $file to save colorifications: $!"
    and return;

  print $fh @ln;
  close $fh;

  1
}

sub load_colorified {
  my ($file) = @_;

  my %loaded;
  return \%loaded unless -e $file;

  open my $fh, '<', $file
      or warn "Could not open $file to restore colorifications: $!"
      and return;
  my @in = readline($fh);
  close $fh;

  while ($_ = shift @in) {
    chomp;
    my ($nick,$val) = split ' ';
    $loaded{ lc($nick) } = $val;
  }

  \%loaded
}

__END__
