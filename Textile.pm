# ---------------------------------------------------------------------------
# Text::Textile
# A module for perl
#
# Release 1.0
# March 18, 2003
#
# Original code from Brad Choate
# http://www.bradchoate.com/
#
# Modified March 2003 by Tom Insam <http://jerakeen.org> to become
# Text::Textile
#
# ---------------------------------------------------------------------------
# This software is provided as-is.
# You may use it for commercial or personal use.
# If you distribute it, please keep this notice intact.
#
# Copyright (c) 2003 Brad Choate
# ---------------------------------------------------------------------------

package Text::Textile;
our $VERSION=0.5;

use warnings;
use strict;
use HTML::Entities;
use Exporter;
use base qw(Exporter);
our @EXPORT_OK = ('textile');

=head1 NAME

Text::Textile

=head1 SYNOPSIS

    use Text::Textile qw(textile);
    
    my $text = "Hi there\n\This is my web page\n";
    my $html = textile($text);
    print $html;
    
=head1 DESCRIPTION

Text::Textile implements the Textile formatting language as outlined at
http://www.textism.com/tools/textile/. The actual code was written by Brad  
Choate (http://www.bradchoate.com/) for his Movable Type plugin
(http://www.bradchoate.com/past/mttextile.php). I've stolen the code, thrown 
away most of the wrapper, and added an exportable function. Not complex
stuff.              

=head1 LICENSE

This software is provided as-is.
You may use it for commercial or personal use.
If you distribute it, please keep this notice intact.

Textile formatting code copyright (c) 2003 Brad Choate

=head1 CREDITS

All the clever things in Text::Textile were written by Brad Choate
E<lt>http://www.bradchoate.comE<gt>. The module wrappers, POD, tests and
other misc 'become a module' stuff was slapped on the top by Tom Insam
E<lt>tom@jerakeen.orgE<gt>. I asked Brad, he doesn't mind..

=head1 BUGS

I need more tests, mostly. The actual implementation I want to touch as
little as possible, I feel accuracy to the original more important than
fixing rendering weirdness. This attitude may change..

=cut

sub textile {
    my ($str) = @_;

    my %macros = ('bq' => 'blockquote');
    my %qtags = ('\*' => 'strong',
                 '\?\?' => 'cite',
                 '-' => 'del',
                 '\+' => 'ins',
                 '~' => 'sub');

    # a URL discovery regex. This is from Mastering Regex from O'Reilly
    my $urlre = qr{
        # Match the leading part (proto://hostname, or just hostname)
        (
            # ftp://, http://, or https:// leading part
            (ftp|https?|telnet|nntp)://[-\w]+(\.\w[-\w]*)+
          |
            # or, try to find a hostname with our more specific sub-expression
            (?i: [a-z0-9] (?:[-a-z0-9]*[a-z0-9])? \. )+ # sub domains
            # Now ending .com, etc. For these, require lowercase
            (?-i: com\b
                | edu\b
                | biz\b
                | gov\b
                | in(?:t|fo)\b # .int or .info
                | mil\b
                | net\b
                | org\b
                | museum\b
                | aero\b
                | coop\b
                | name\b
                | pro\b
                | [a-z][a-z]\b # two-letter country codes
            )
        )?

        # Allow an optional port number
        ( : \d+ )?

        # The rest of the URL is optional, and begins with / . . . 
        (
             /
             # The rest are heuristics for what seems to work well
             [^.!,?;"'<>()\[\]{}\s\x7F-\xFF]*
             (?:
                [.!,?;]+  [^.!,?;"'<>()\[\]{}\s\x7F-\xFF]+
             )*
        )?
    }x;

    my $punct = quotemeta(q{!'#$%&`()*+,-./:;<=>?@[/]^_{|}~});
    my $punctre = qr{[$punct]};

    # strip out line breaks within pre blocks for restoration later...
    $str =~ s|(<pre.*?>)(.+?)(</pre>)|"\n\n".$1._savebreaks($2).$3."\n\n"|ges;
    $str =~ s!(<(h[1-6]|p|pre|blockquote).*?>)(.+?)(</\2>)!"\n\n".$1.$3.$4."\n\n"!ges;

    $str =~ s/\r//g;
    my @paras = split /\n{2,}/, $str;
    my $out = '';

    my $in_pre = 0;
    my $no_fmt = 0;

    foreach my $para (@paras) {
        $para =~ s/\s+$//;
        $para =~ s/^\s+//;
        next unless $para;

        my $pb = '';
        my $ps = '';
        my $fmt = '';
        my @lines;
        if ($no_fmt) {
            $fmt = $para;
        } elsif ($para =~ m/^(h[1-6]|p|bq)(\((.+?)\))?\. /g) {
            # block macros: h[1-6](style)., bq(style).
            $pb = $1;
            $ps = $3;
            $para = substr($para, pos($para));
            @lines = split /\n/, $para;
        } elsif ($para =~ m/^\* /) {
            # '* ' prefix means an un-ordered list
            $pb = 'ul';
            $para =~ s/^\* //;
            @lines = split /\n\* /, $para;
            s/\n/<br \/>\n/g foreach @lines;
        } elsif ($para =~ m/^# /) {
            # '# ' prefix means an ordered list
            $para =~ s/^# //;
            $pb = 'ol';
            @lines = split /\n\# /, $para;
            s/\n/<br \/>\n/g foreach @lines;
        } elsif ($para =~ m/^\|/) {
            # handle wiki-style tables
            $fmt = _mktable($para);
        } elsif ($para =~ m/<table.*?>/) {
            $fmt = $para;
        } elsif ($para =~ m/^==/) {
            $para =~ s/^==//;
            $fmt = $para;
            $no_fmt = 1;
        } else {
            @lines = split /\n/, $para;
        }

        $in_pre = 1 if $para =~ m|<pre[ >]|;

        for (my $i = 0; $i <= $#lines; $i++) {
            my $lb = '';
            my $line = $lines[$i];
            chomp $line;

            $lb = 'li' if $pb eq 'ol' || $pb eq 'ul';
            $lb ||= 'br' unless $in_pre;

            if ($lb eq 'br') {
                $fmt .= $line;
                $fmt .= '<br />'."\n" if $i < $#lines;
            } elsif ($lb) {
                $fmt .= '<' . $lb . '>' . $line . '</' . $lb . '>' . "\n";
            } else {
                $fmt .= $line;
            }
        }

        $pb ||= 'p' if !$in_pre && !$no_fmt && $fmt !~ m/<(h[1-6]|p|pre|blockquote)[ >]/;
        $out .= '<'. ($macros{$pb} || $pb) . ($ps ? qq{ class="$ps"} : '') . '>' if $pb;
        $out .= '<p>' if ($pb eq 'bq') && $fmt !~ m/<p[ >]/;

        if (!$in_pre && !$no_fmt) {
            # final pass for encoding
            my $tokens = _tokenize($fmt);
            $fmt = '';
            foreach my $t (@$tokens) {
                my $text = $t->[1];
                if ($t->[0] eq 'tag') {
                    $text =~ s/&(?!amp;)/&amp;/g;
                    $fmt .= $text;
                } else {
                    my $repl = [];
                    $text = encode_html($text); 
                    $text =~ s!&amp;quot;!&#34;!g;
                    $text =~ s!&amp;(([a-z]+|#\d+);)!&$1!g;
                    $text =~ s|&quot;|"|g;

                    # These create markup with entities. Do first and 'save' result for later:
                    # "text":url -> hyperlink
                    $text =~ s|"([^"\(]+)\s?(\([^\(]*\))?":($urlre)|_repl($repl,_mklink($1,$2,$3))|ge;
                    # !blah (alt)! -> image
                    $text =~ s!(^|\s|>)\!(\([A-Za-z0-9_\-]+\))?([^\s\(]+)((\([^\)]+\)|[^\!]+)*)\!(:$urlre)?!$1._repl($repl,_mkimage($3,$4,$6,$2))!gem;

                    # ABC(Aye Bee Cee) -> acronym
                    $text =~ s|([A-Z][A-Z0-9]+)\((.+?)\)|_repl($repl,qq{<acronym title="$2">$1</acronym>})|ge;
                    # ABC -> 'capped' span
                    $text =~ s/(^|[^"][>\s])([A-Z][A-Z0-9\., ]+)([^<a-z0-9]|$)/$1._repl($repl,qq{<span class="caps">$2<\/span>}).$3/ge;

                    # simple replacements...
                    # _blah_ -> emphasis
                    $text =~ s!(^|\s)_([^\s][^_]*[^\s])_($punctre{0,2})($|\s)!$1<em>$2</em>$3$4!gm;

                    # macros -- applied to non 'pre' blocks:
                    foreach my $f (keys %qtags) {
                        my $r = $qtags{$f};
                        $text =~ s!(^|\s|>)$f\b(.+)\b($punctre*)$f(($punctre{0,2})(\s|$)|<)!$1<$r>$2$3</$r>$4!gm;
                    }

                    $text =~ s!\^(.*)\^!<sup>$1</sup>!gm;


                    # (tm) -> &trade;
                    $text =~ s|\(TM\)|&trade;|gi;
                    # (c) -> &copy;
                    $text =~ s|\(C\)|&copy;|gi;
                    # (r) -> &reg;
                    $text =~ s|\(R\)|&reg;|gi;
                    # nxn -> n&times;n
                    $text =~ s|(\d+)x(\d)|$1&times;$2|g;

                    # translate these encodings to the Unicode equivalents:
                    $text =~ s/&#133;/&#8230;/g;
                    $text =~ s/&#145;/&#8216;/g;
                    $text =~ s/&#146;/&#8217;/g;
                    $text =~ s/&#147;/&#8220;/g;
                    $text =~ s/&#148;/&#8221;/g;
                    $text =~ s/&#150;/&#8211;/g;
                    $text =~ s/&#151;/&#8212;/g;

                    $text =~ s|"|&quot;|g;

                    # Restore replacements done earlier:
                    my $i = 0;
                    $i++, $text =~ s/ <$i> /$_/ foreach @$repl; 

                    $fmt .= $text;
                }
            }
        } elsif ($in_pre) {
            # encode textual portion of pre block
            $fmt = encode_html($fmt);
            $fmt =~ s|&lt;(/?code.*?)&gt;|<$1>|g;
            $fmt =~ s|&lt;(/?pre.*?)&gt;|<$1>|g;
        }
    
        if ($no_fmt && $fmt =~ m|==$|s) {
            $no_fmt = 0;
            $fmt =~ s/==$//s;
        }

        $out .= $fmt;
        $out .= '</p>' if ($pb eq 'bq') && $fmt !~ m/<p[ >]/;
        $out .= '</' . ($macros{$pb} || $pb) .'>' if $pb;
        $out .= "\n\n" if $pb || $no_fmt;

        $in_pre = 0 if $para =~ m|</pre>|;
    }
    $out =~ s/\n\n$//s;

    # restore line breaks within 'pre' blocks:
    $out =~ s/&#28;/\n/gs;
    return $out;
}

sub _repl {
    push @{$_[0]}, $_[1];
    ' <'.(scalar(@{$_[0]})).'> ';
}

sub _mktable {
    my ($str) = @_;

    my @rows = split /\n/, $str;
    my $col_count = 0;
    foreach my $row (@rows) {
        my $cnt = $row =~ m/\|/;
        $col_count ||= $cnt;
        # ignore block if columns aren't even.
        return $str if $cnt != $col_count;
    }
    my $out = '';
    foreach my $row (@rows) {
        my @cols = split /\|/, $row.' ';
        my $span = 0;
        my $row_out = '';
        for (my $c = $#cols-1; $c > 0; $c--) {
            my $col = $cols[$c];
            $col =~ s/^ +//; $col =~ s/ +$//;
            if (length($col)) {
                $row_out = '<td' .($span?' colspan="'.($span+1).'"':'') . ">$col</td>"
                    . $row_out;
                $span = 0 if $span;
            } else {
                $span++;
            }
        }
        $row_out = qq{<td colspan="$span"></td>$row_out} if $span;
        $out .= "<tr>$row_out</tr>\n";
    }
    qq{<table cellspacing="0" border="1">$out</table>};
}

sub _savebreaks {
    $_ = shift;
    return '' unless $_;
    s/\n/$;/gs;
    $_;
}

sub _mkimage {
    my ($src, $extra, $link, $style) = @_;
    return '!!' if length($src) == 0;
    my $tag  = qq{<img src="$src"};
    if ($style) {
        $style =~ s/^\(//;
        $style =~ s/\)$//;
        $tag .= qq{ class="$style"};
    }
    my ($pctw, $pcth, $w, $h);
    if ($extra) {
        my ($alt) = $extra =~ m/\(([^\)]+)\)/;
        $extra =~ s/\([^\)]+\)// if $alt;
        my ($pct) = ($extra =~ m/(^|\s)(\d+)%(\s|$)/)[1];
        if (!$pct) {
            ($pctw, $pcth) = ($extra =~ m/(^|\s)(\d+)%x(\d+)%(\s|$)/)[1,2];
        } else {
            $pctw = $pcth = $pct;
        }
        if (!$pctw && !$pcth) {
            ($w,$h) = ($extra =~ m/(^|\s)(\d+)x(\d+)(\s|$)/)[1,2];
            if (!$w) {
                ($w) = ($extra =~ m/(^|[,\s])(\d+)w([\s,]|$)/)[1];
            }
            if (!$h) {
                ($h) = ($extra =~ m/(^|[,\s])(\d+)h([\s,]|$)/)[1];
            }
        }
        if ($alt) {
            $tag .= qq{ alt="$alt"};
        }
    }
    if ($w && $h) {
        $tag .= qq{ height="$h" width="$w"};
    }
    $tag .= " />";
    if ($link) {
        $link =~ s/^://;
        $tag = '<a href="'.$link.'">'.$tag.'</a>';
    }
    $tag;
}

sub _mklink {
    my ($text, $title, $url) = @_;
    if ($url !~ m|^/|) {
        $url = "http://$url" if $url !~ m!^(https?|ftp|mailto|nntp|telnet)!;
    }
    $url =~ s/&(?!amp;)/&amp;/g;
    my $tag = qq{<a href="$url"};
    if ($title) {
        $title =~ s/^\(//;
        $title =~ s/\)$//;
        $tag .= qq{ title="$title"};
    }
    $tag .= qq{>$text</a>};
    $tag;
}

sub _tokenize {
    my ($str) = @_;
    my $pos = 0;
    my $len = length $str;
    my @tokens;

    # pattern to match balanced nested <> pairs, up to two levels deep:
    my $nested_angles = qr/<(?:[^<>]|<[^<>]*>)*>/;

    while ($str =~ m/($nested_angles)/gs) {
        my $whole_tag = $1;
        my $sec_start = pos $str;
        my $tag_start = $sec_start - length $whole_tag;
        if ($pos < $tag_start) {
            push @tokens, ['text', substr($str, $pos, $tag_start - $pos)];
        }
        push @tokens, ['tag', $whole_tag];
        $pos = pos $str;
    }
    push @tokens, ['text', substr($str, $pos, $len - $pos)] if $pos < $len;
    \@tokens;
}

sub encode_html {
    my($html) = @_;
    return '' unless defined $html;
    $html = HTML::Entities::encode_entities($html);
}

1;
