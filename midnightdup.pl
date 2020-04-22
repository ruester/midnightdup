#!/usr/bin/perl

use strict;
use warnings;
use utf8;

use Tk;
use File::Find;
use File::Temp;
use Cwd qw(cwd);
use Digest::MD5 qw(md5_hex);
use Digest::MD5::File qw(file_md5_hex);
use Number::Bytes::Human qw(format_bytes);

use constant SEP => '..__~~--##SEPERATOR##--~~__..';
use constant SEPREGEX => '\.\.__~~--##SEPERATOR##--~~__\.\.';

use Data::Dumper;

$Digest::MD5::File::NOFATALS = 1;

sub dialog {
    our $mw;
    $mw->messageBox(-message => shift);
}

# https://docstore.mik.ua/orelly/perl3/tk/ch15_02.htm
sub BindMouseWheel {
   my ($w) = @_;
   if ($^O eq "MSWin32")
   {
      $w->bind('<MouseWheel>' => [ sub { $_[0]->yview('scroll', -($_[1]/120)*3, 'units') }, Ev('D') ] );
   }
   else
   {
      # Support for mousewheels on Linux commonly comes through
      # mapping the wheel to buttons 4 and 5. If you have a
      # mousewheel ensure that the mouse protocol is set to
      # "IMPS/2" in your /etc/X11/XF86Config (or XF86Config-4)
      # file:
      # Select "InputDevice"
      #     Identifier "Mouse0"
      #     Driver "mouse"
      #     Option "Device" "/dev/mouse"
      #     Option "Protocol" "IMPS/2"
      #     Option "Emulate3Buttons" "off"
      #     Option "ZAxisMapping" "4 5"
      # EndSection
      $w->bind('<4>', => sub {
         $_[0]->yview('scroll', -3, 'units') unless $Tk::strictMotif;
      });
      $w->bind('<5>' => sub {
         $_[0]->yview('scroll', +3, 'units') unless $Tk::strictMotif;
      });
   }
}

sub process_file {
    our $tmpfilename;
    our $tmpfh;

    my $name;
    my $shortmd5;
    my $buffer;
    my $content;

    $name = $File::Find::name;

    if ( -d $name or ! -f $name ) {
        return 0;
    }

    open(FILE, $name) or return;
    binmode FILE;

    $content = read(FILE, $buffer, 1024);

    $shortmd5 = md5_hex($buffer);

    $tmpfh->seek(0, SEEK_END);
    printf $tmpfh "%s%s%s\n", ($shortmd5, SEP, $name);
    $tmpfh->flush();

    our $filecount;
    $filecount++;

    our $waitlabel;

    $waitlabel->configure(
        -text => 'Searching... ' . $filecount
    );
    $waitlabel->update();
}

sub start_search {
    our $dir;
    our $tmpfh;
    our $filecount;
    our $waitlabel;
    my @DIRLIST = ( $dir );
    my %result;
    my @dups;

    my $start = time();

    if (! -d $dir) {
        dialog('Dir not found');
        return 1;
    }

    find(\&process_file, @DIRLIST);

    $waitlabel->configure(
        -text => 'Processing...',
    );
    $waitlabel->update();

    $tmpfh->seek(0, SEEK_SET);

    # read results and sort by short md5 sum
    while (my $line = <$tmpfh>) {
        chomp $line;
        my @tokens = split SEPREGEX, $line;
        push(@{ $result{$tokens[0]} }, $tokens[1]);
    }

    # filter out unique files
    foreach my $key (keys %result) {
        my @arr = @{ $result{$key} };
        if (scalar(@arr) == 1) {
            delete($result{$key});
        }
    }

    # md5_hex over whole duplicate files in group
    foreach my $key (keys %result) {
        my @arr = @{ $result{$key} };
        my @md5sums;

        # remove guess
        delete($result{$key});

        # run md5 over complete files and add to hash
        foreach my $file (@arr) {
            my $sum = file_md5_hex($file);
            last unless defined $sum;
            my @tmparr = ($sum, $file);
            push(@{ $result{$sum} }, $file);
        }
    }

    # filter out unique files
    foreach my $key (keys %result) {
        my @arr = @{ $result{$key} };
        if (scalar(@arr) == 1) {
            delete($result{$key});
        }
    }

    my @sort;
    my $alltotal = 0;

    # sort by savable amount
    foreach my $key (keys %result) {
        my @arr = @{ $result{$key} };
        my $size = (stat $arr[0])[7];
        my @tmparr = ($size * (scalar(@arr) - 1), \@arr);
        push(@sort, \@tmparr);
    }

    @sort = sort { $b->[0] <=> $a->[0] } @sort;

    # show duplicates in listbox
    foreach my $a (@sort) {
        my @arr = @$a;
        my $total = $arr[0];
        my @files = @{$arr[1]};

        $alltotal += $total;

        $total = format_bytes($total, bs => 1000, si => 1);
        push(@dups, $total . " can be saved");

        for (my $i = 0; $i <= $#files; $i++) {
            my $stripdir = $dir . '/' if $dir !~ m|/$|;
            $files[$i] =~ s/\Q${stripdir}//;
        }

        push(@dups, @files);
        push(@dups, "");
    }

    my $additional = "";

    if (scalar(@dups) == 0) {
        push(@dups, "No duplicates found.");
    } else {
        $additional =
            "a total of "
            . format_bytes($alltotal, bs => 1000, si => 1)
            . " can be saved.";
    }

    our $listbox->configure(
        -listvariable => \@dups,
    );

    my $stop = time();

    $waitlabel->configure(
        -text => 'Finished ('
            . $filecount
            . ' files compared in ' . ($stop - $start) . ' seconds) '
            . $additional,
    );
    $waitlabel->update();
}

our $filecount = 0;
our $tmpfh;
our $dir = cwd;
our $mw = MainWindow->new();

$mw->title('MidnightDup - Duplicate File Finder');

my $label = $mw->Label(
	-text => 'Path to search:',
);

our $waitlabel = $mw->Label(
	-text => '',
);

my $dirlabel = $mw->Label(
	-text => $dir,
);

my $dir_btn = $mw->Button(
	-text		=> 'Choose directory',
	-command	=> sub{
        our $dir;
		if( $dir = $mw->chooseDirectory ) {
			$dirlabel->configure(-text => $dir);
		} else {
            $dir = '';
            $dirlabel->configure(-text => $dir);
        }

        my @empty = ('');

        our $listbox;

        $listbox->configure(
            -listvariable => \@empty,
        );

        $listbox->update();

        our $waitlabel->configure(
            -text => '',
        );
	},
);

our $listbox = $mw->Scrolled('Listbox',
    -scrollbars => 'e',
    -height => 50,
);

my $search_btn = $mw->Button(
	-text		=> 'Search for duplicate files',
	-command	=> sub{
        # create a new temp file
        our $tmpfh = File::Temp->new(SUFFIX => '.dupldat');

        binmode($tmpfh, ":utf8");
        $tmpfh->unlink_on_destroy(1);

        our $waitlabel->configure(
            -text => 'Searching...'
        );

        my @empty = ('');

        our $listbox;

        $listbox->configure(
            -listvariable => \@empty,
        );

        $listbox->update();

		start_search()
	},
);

$label->pack(
    -anchor => 'nw',
);

$dir_btn->pack(
    -anchor => 'nw',
    -after => $label,
);

$dirlabel->pack(
    -anchor => 'nw',
    -after => $dir_btn,
);

$search_btn->pack(
    -anchor => 'nw',
    -after => $dirlabel,
);

$waitlabel->pack(
    -anchor => 'nw',
    -after => $search_btn,
);

$listbox->pack(
    -after => $waitlabel,
    -fill => "both",
);

$mw->geometry('800x600+100+100');
$listbox->focus();

&BindMouseWheel($listbox);

$mw->MainLoop();
