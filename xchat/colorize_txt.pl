use strict; use warnings FATAL => 'all';
use Xchat; use 5.10.1; my $VERSION = '0.61';

### Default should be fine:
my $save_path = get_save_location("colorified.cf")
  or die "Could not determine a safe save location";
## Everything else is configurable via /colorify -set
## You can alter color names below, if you're playing with Local Color hues.
##
## Change the color of a user's channel text (and their nick)
## Licensed under the same terms as Perl 5
##   - Jon Portnoy  avenj@cobaltirc.org
##
## CAVEATS:
##  Currently fails if you're stripping colors ..
##   . . not sure if overriding is the Right Thing To Do
## TODO:
##  Bold / underline attribs?
##
##  Does not currently handle per-context casemap
##  (cheaps out and uses lc())


my %col_by_name = qw/
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


 #####################################################
 #### Nothing past here is manually configurable. ####
 #####################################################


## Manage these via /colorify -set :
my $opts = +{
  nick_only     => 0,
  except_nicks  => 0,
  color_private => 0,
};


my %name_by_col = reverse %col_by_name;
my %nicks;

use Scalar::Util 'looks_like_number';

Xchat::register('ColorizeTxt', $VERSION, "Colorize text from users");

Xchat::print("o hai, colorizer thingo $VERSION loaded");
Xchat::print($_) for (
  "-> Add via /colorify <nick> <color>",
  "-> Del via /decolorify <nick>",
  "-> List current via /colorify",
  "-> List colors via /colorify -colors",
  "-> View settings via /colorify -set",
  "-> Change via /colorify -set <opt> <value>",
);

Xchat::hook_print($_, \&colorify,
  {
    data     => $_,
    priority => Xchat::PRI_HIGH,
  },
) for 'Channel Message', 'Channel Action',
      'Channel Msg Hilight', 'Channel Action Hilight',
      'Private Message', 'Private Action',
      'Private Message to Dialog',
      'Private Action to Dialog';

Xchat::hook_command( $_, \&cmd_colorify,
  {
    help_text => "Colorify/decolorify text from users",
  },
) for qw/colorify decolorify uncolorify/;


sub colorify {
  my $event = $_[1];
  return Xchat::EAT_NONE 
    if not $opts->{color_private} and index($event, 'Private') == 0;

  my ($nick, $first) = @{ $_[0] };

  my $colorify = get_color_for(
    lc( $nick || return Xchat::EAT_NONE )
  );

  return Xchat::EAT_NONE
    if not defined $first
    or not $colorify;

  my $last  = $_[0]->[-1];

  unless ($opts->{nick_only}) {
    $_[0]->[1]   = "\003" . $colorify . $first;
    ## FIXME unneeded..? too lazy to check
    $_[0]->[-1] .= "\003";
  }

  if ($opts->{nick_only} || !$opts->{except_nicks}) {
    $_[0]->[0] = "\003" . $colorify . $nick ."\003";
  }

  Xchat::emit_print($event, @{ $_[0] });
  Xchat::EAT_ALL
}

sub __cmd_colorify_list_colors {
  Xchat::print(' -> Available colors:');
  for my $col_name (sort keys %col_by_name) {
    Xchat::print(" \003".$col_by_name{$col_name} . $col_name."\003")
  }

  Xchat::EAT_ALL
}

sub __cmd_colorify_set {
  my ($param, $value) = @_;

  unless ($param) {
    Xchat::print("-> Current colorifier settings:");
    while (my ($k,$v) = each %$opts) {
      Xchat::print("  $k : $v");
    }
    return Xchat::EAT_ALL
  }

  unless (defined $value) {
    if (defined $opts->{$param}) {
      my $v = $opts->{$param};
      Xchat::print("  $param : $v")
    } else {
      Xchat::print("No such setting $param")
    }
    return Xchat::EAT_ALL
  }

  unless (exists $opts->{$param}) {
    Xchat::print("Cannot set unknown option $param");
    return Xchat::EAT_ALL
  }

  $value = 0 if lc($value) eq 'off';
  $opts->{$param} = $value;
  Xchat::print("  $param : $value");

  save_colorified();

  Xchat::EAT_ALL
}


sub cmd_colorify {
  my ($cmd, @args) = @{ $_[0] };

  my $nick = lc($args[0] || '');

  %nicks = %{ load_colorified() } unless keys %nicks;

  unless ($nick) {
    Xchat::print("Current colorifications:");
    for my $this_nick (sort keys %nicks) {
      my $col_code = $nicks{$this_nick};
      my $col_name = $name_by_col{$col_code} // $col_code;
      Xchat::print(" \003".$col_code."$this_nick is $col_name ($col_code)\003");
    }
    return Xchat::EAT_ALL
  }

  return __cmd_colorify_list_colors             if $nick eq '-colors';
  return __cmd_colorify_set(@args[1 .. $#args]) if $nick eq '-set';

  if ($cmd eq 'colorify') {
    my $opt = $args[1];
    my ($col_name, $col_code);

    unless (defined $opt) {
      ## Requesting current color for a user.
      if (defined $nicks{$nick}) {
        $col_code = $nicks{$nick};
        $col_name = $name_by_col{$col_code};
        Xchat::print(" \003".$col_code.$nick." is $col_name ($col_code)\003");
      } else {
        Xchat::print("User '$nick' is not currently colorifed.");
      }
      return Xchat::EAT_ALL
    }

    if (index($nick, '%') == 0 || index($nick, '-') == 0) {
      ## Reserved for config/flags.
      Xchat::print("Nickname is noit valid ($nick)");
      return Xchat::EAT_ALL
    }

    $opt = lc $opt;

    if (looks_like_number $opt) {
      $col_code = $opt;
      unless ($col_name = $name_by_col{$opt}) {
        Xchat::print("Warning; do not have a name for color code $opt");
        $col_name = $opt
      }
    } else {
      unless ($col_code = $col_by_name{$opt}) {
        Xchat::print("No color code found for color '$opt'");
        return Xchat::EAT_ALL
      }
      $col_name = $opt;
    }

    $nicks{$nick} = $col_code;
    Xchat::print("coloring $nick $col_name ($col_code)");
    save_colorified();

  } elsif ($cmd eq 'decolorify' || $cmd eq 'uncolorify') {
    unless (delete $nicks{$nick}) {
      Xchat::print("Do not have colorified nick $nick");
      return Xchat::EAT_ALL
    }
    Xchat::print("decoloring $nick");
    save_colorified();

  } else {
    Xchat::print("what the fuck? fell through in cmd_colorify")
  }

  Xchat::EAT_ALL
}

sub get_color_for {
  my ($nick) = @_;

  ## Get nick -> color code map.
  %nicks = %{ load_colorified() } unless keys %nicks;
  my $col_code = $nicks{$nick} || return;

  unless (looks_like_number $col_code) {
    Xchat::print("$nick has unknown color $col_code");
    return
  }

  $col_code
}

sub get_save_location {
  my ($file) = @_;
  my $dir = Xchat::get_info('xchatdir')  ## X-Chat
    || Xchat::get_info('configdir');     ## HexChat

  unless ($dir) {
    warn "get_save_location could not determine a configdir";
    return
  }

  require File::Spec;
  File::Spec->catfile($dir, $file)
}

sub save_colorified {
  die "No path to save to" unless $save_path;
  my @ln;
  while (my ($key,$val) = each %$opts) {
    push @ln, "% $key $val\n";
  }
  while (my ($key,$val) = each %nicks) {
    push @ln, "$key $val\n";
  }

  open my $fh, '>', $save_path
    or warn "Could not open $save_path to save colorifications: $!"
    and return;

  print $fh @ln;
  close $fh;

  1
}

sub load_colorified {
  my %loaded;
  return \%loaded unless -e $save_path;

  open my $fh, '<', $save_path
      or warn "Could not open $save_path to restore colorifications: $!"
      and return;
  my @in = readline($fh);
  close $fh;

  while (my $line = shift @in) {
    chomp $line;
    my @pieces = split ' ', $line;

    if ($pieces[0] eq '%') {
      my ($param,$val) = @pieces[1,2];
      unless (exists $opts->{$param}) {
        Xchat::print("Warning; dropped unknown option $param");
        next
      }
      $opts->{$param} = $val;
      next
    }

    my ($nick,$val) = @pieces;

    unless ( looks_like_number($val) ) {
      ## Backwards-compat.
      if (defined $col_by_name{$val}) {
        ## If we know what this symbolic name is, use that value.
        $val = $col_by_name{$val};
        Xchat::print("Converted old-style config for $nick")
      } else {
        ## Otherwise warn and kill the line.
        Xchat::print("Warning; could not convert old-style config for $nick");
        Xchat::print("  (do not recognize symbolic color name $val)");
        next
      }
    }

    $loaded{ lc($nick) } = $val;
  }

  \%loaded
}

__END__
RIP Stephanie Michelle Page, taken by cancer 3-13-2014
