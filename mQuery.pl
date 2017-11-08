use 5.014;

use strict;
use warnings 'all';
#no warnings 'experimental::smartmatch';

# Fast but not in core
# use JSON::XS;

use JSON::PP 'decode_json';
use open qw(:std :encoding(UTF-8));
use utf8;


# ===== MAIN =====

# --- use HTTPS ---
use constant HTTPS
  => 'https://';

# --- Presentation detail link ---
use constant DETAIL_URI
  => '/Mediasite/manage#module=Sf.Manage.PresentationSummary&args[id]=';

# --- Mediasite URIs ---
my %m = (
  tree    => {
    URI  => '/Mediasite/Manage/Folder/GetInitialFolderTree',
    PAYLOAD   => '{"RootFolder":null}',
  },
  folder  => {
    URI  => '/Mediasite/Manage/Folder/GetFoldersInFolder',
    PAYLOAD   => '{"RootFolder":"{{ID}}"}',
  },
  list    => {
    URI  => '/Mediasite/Manage/Grid/GetListOptimized',
    
    # SORT by Name
    # set "rows" from 15 to 1000
    PAYLOAD   => '{"page":"0","rows":"1000","sortOrder":"Ascending","sortBy":"Sort_Name","searchBy":null,"facets":[],"Id":"{{ID}}","id":"{{ID}}"}',
  },
  detail  => {
    URI  => '/Mediasite/Manage/Presentation/GetDisplay',
    PAYLOAD   => '{"Id":"{{ID}}","DisplayRecordedNotice":true}',
  },
);

# --- OPTIONS ---
my $STREAMS = (shift // '') eq '--streams';

# ----- RUN -----

mQuery($ENV{M_HOST}, $ENV{M_AUTH});

# ================


=head2 mQuery

Query Mediasite EVP for video streams

=cut

sub mQuery {
  # --- set up AUTH ---
  my $auth = {
    HOST  => (shift // die "Setup ENV first\n"),
    AUTH  => (shift // die "Setup ENV first\n"),
  };

  # --- currently 'streams' option only ---
  die "Must specify an option, like --streams\n" unless $STREAMS;

  # --- Root folder ---
  my $tree = get_tree(API($auth, payload($m{tree}, '')))
    # Optionally set custom Folder ID
    // { Id => '4c32c0e5155b4298a701d773a1ad4dac14', Name => 'Root' };

  # --- Traverse ---
  my @tree = $tree;

  NODE:
  while (@tree) {
    my $node = pop @tree;

#    push @tree, reverse get_folder(API(
#        $auth,
#        payload($m{folder}, $node->{Id})
#    ));

    # iterator
    my $items = get_list(API(
        $auth,
        payload($m{list}, $node->{Id})
    ));

    # Remove 'reverse' for going bottom up
    push @tree, reverse @{ $items->{folder} };

    VIDEO:
    for my $video (@{ $items->{video} }) {
      # skip scheduled presentations
      next VIDEO if $video->{Status} eq 'Scheduled';

      if ($STREAMS) {
        my $url = HTTPS . $auth->{HOST} . DETAIL_URI . $video->{Id};
        my $path = join ' >> ', @{ $node->{Path}};

        my %stream = get_detail(API(
            $auth,
            payload($m{detail}, $video->{Id})
        ));
        my $streams = join ' ', map { qq([$_:$stream{$_}]) } sort keys %stream;

        say qq($url | ($path) $video->{Name} $streams);
      }
      elsif (1) {
        # possibly add more options here
      }
    }

    # FLUSH buffer
    $| = 1;
  }
}

=head2 get_tree

Get InitialFolderTree

=cut

sub get_tree {
  # cursor
  my $c = shift;
  # root folder
  my $tree = $c->{Folders}->[0]->{Children}->[1]
    // die "Fatal error\n";

  return {
    Id => $tree->{Id},
    Name => $tree->{Name},
    Path => [ $tree->{Name} ],
  };
}

=head2 get_folder

Get next folders

=cut

sub get_folder {
  # cursor
  my $c = shift;

  my @f;
  for my $f (@{ $c->{Folders} }) {
    push @f, { Id => $f->{Id}, Name => $f->{Name} };
  }

  return @f;
}


=head2 get_list

=cut

sub get_list {
  # cursor
  my $c = shift;

  # iterator
  my %item = ( folder => [], video => [] );

  for my $row (@{ $c->{Results}->{rows} }) {
    # presentation data
    my $i = $row->{ObjectData};

    # FOLDER
    if ($row->{EntityType} eq 'Folder') {
      my (undef, @path) = ( split('/', $i->{Path}), $i->{Name} );
      push @{ $item{folder} }, {
        Id    => $i->{Id},
        Path  => \@path,
      };
    }
    # VIDEO
    #               skip presentation templates
    elsif ($row->{EntityType} eq 'Presentation') {
      push @{ $item{video} }, {
        Id      => $i->{Id},
        Name    => $i->{Name},
        Status  => $i->{Status},
        # JSON::PP::Boolean
        Private => $i->{IsPrivate},
        # Size in bytes > 0
        Size    => $i->{TotalFileLength},
      };
    }
  }

  return \%item;
}

=head2 API

Send cURL and return decoded response

in:   auth ref, URI ref

=cut

sub API {
  my $auth = shift;
  my $uri  = shift;

  my $data = cURL({
      URL     => HTTPS . $auth->{HOST} . $uri->{URI},
      COOKIE  => 'MediasitePortal=; MediasiteAuth=' . $auth->{AUTH},
      DATA    => $uri->{PAYLOAD},
  });
  # make UTF-8
  utf8::encode($data);

  my $res = decode_json($data);
  die "Bad request, check AUTH\n" unless $res->{ResponseStatus} == 0;

  return $res;
}

sub get_detail {
  # cursor
  my $c = shift;

  # Player name
  # $c->{Presentation}->{Player}->{Name};

  my %stream;
  for my $s (@{ $c->{Presentation}->{ContentStreamCollection}->{Streams} }) {
    
    # STREAMS (video1 and/or video2 and/or slides)

    # (!) video1 and video2 have null slides (ocr)

    # AUDIO
    push @{ $stream{AUDIO} }, 3 if ($s->{Audio} // $s->{PlaybackAudioSource});

    # PLAYBACK
    # video1/video2 input not Completed
    push @{ $stream{PLAYBACK} }, $s->{Status};

    # WMV
    my $wmv = $s->{WMV}->{Status};
    push @{ $stream{WMV} }, $wmv if defined $wmv;

    # MP4
    my $mp4 = $s->{MP4}->{Status};
    push @{ $stream{MP4} }, $mp4 if defined $mp4;

    # SmoothStreaming
    my $ss = $s->{SmoothStreaming}->{Status};
    push @{ $stream{SS} }, $ss if defined $ss;

    # Live Content
    my $live = $s->{Live}->{Status};
    push @{ $stream{LIVE} }, $live if defined $live;

    # SLIDES
    my $slides = $s->{Slides}->{Status};
    push @{ $stream{SLIDES} }, $slides if defined $slides;
    
    # OCR
    my $ocr = $s->{OCR}->{Status};
    push @{ $stream{OCR} }, $ocr if defined $ocr;
  }

  # remap streams state
  for my $s (keys %stream) {
    # Check the state is => 3 <= (Completed) on all the existing video inputs
    $stream{$s} = (map { ($_ == 3) ? () : 1 } @{ $stream{$s} }) ? 'bad' : 'good';
  }

  return %stream;
}

=head2 cURL

Send template cURL request

=cut

sub cURL {
  my $req  = shift;
  my $cURL = qq(curl -s '$req->{URL}' -H 'Pragma: no-cache' -H 'Accept-Encoding: gzip, deflate, br' -H 'User-Agent: mQuery/1.0' -H 'Content-Type: application/json; charset=UTF-8' -H 'Accept: application/json, text/javascript, */*; q=0.01' -H 'Cache-Control: no-cache' -H 'X-Requested-With: XMLHttpRequest' -H 'Cookie: $req->{COOKIE}' -H 'Connection: keep-alive' --data-binary '$req->{DATA}' --compressed);

  return do {
    no warnings;
    join '', qx!$cURL! || die "cURL bad\n";
  };
}

=head2 payload

Inject a folder ID into URI template

=cut

sub payload {
  my %uri = %{ shift @_ };
  my $id  = shift;
  
  $uri{PAYLOAD} =~ s|{{ID}}|$id|g;
  
  return { %uri };
}
