package Text::Textile;
our $VERSION = 0.6;

use strict;
use warnings::register;

use Exporter;
@Text::Textile::ISA = qw(Exporter);
our @EXPORT_OK = qw(textile);
use File::Spec;

sub new {
    my $class = shift;
    my $self = bless {
        named_filters => {},
        text_filters => [],
    }, $class;
    $self->charset('iso-8859-1');
    $self->flavor('xhtml1');
    return $self;
}

sub flavor {
    my $self = shift;
    if (@_) {
        my $flavor = shift;
        $self->{flavor} = $flavor;
        if ($flavor =~ m/^xhtml/) {
            if ($flavor eq 'xhtml1') {
                $self->{line_open} = '';
                $self->{line_close} = '<br />';
                $self->{blockcode_open} = '<pre><code>';
                $self->{blockcode_close} = '</code></pre>';
            } elsif ($flavor eq 'xhtml2') {
                $self->{line_open} = '<l>';
                $self->{line_close} = '</l>';
                $self->{blockcode_open} = '<blockcode>';
                $self->{blockcode_close} = '</blockcode>';
            } else {
                die "bad flavour";
            }
        } elsif ($flavor eq 'html') {
            $self->{line_open} = '';
            $self->{line_close} = '<br>';
        } else {
            die "bad flavor";
        }
    }
    $self->{flavor};
}

sub charset {
    my $self = shift;
    if (@_) {
        $self->{charset} = shift;
        if ($self->{charset} eq 'utf-8') {
            $self->char_encoding(0);
        } else {
            $self->char_encoding(1);
        }
    }
    $self->{charset};
}

sub process {
    my $self = shift;
    $self->textile(@_);
}

sub docroot {
    my $self = shift;
    if (@_) {
        $self->{docroot} = shift;
    }
    $self->{docroot};
}

sub filter_param {
    my $self = shift;
    if (@_) {
        $self->{filter_param} = shift;
    }
    $self->{filter_param};
}

sub named_filters {
    my $self = shift;
    if (@_) {
        $self->{named_filters} = shift;
    }
    $self->{named_filters};
}

sub text_filters {
    my $self = shift;
    if (@_) {
        $self->{text_filters} = shift;
    }
    $self->{text_filters};
}

sub char_encoding {
    my $self = shift;
    if (@_) {
        $self->{char_encoding} = shift;
    }
    $self->{char_encoding};
}

# a URL discovery regex. This is from Mastering Regex from O'Reilly.
# Some modifications by Brad Choate <brad@bradchoate.com>
my $urlre = qr{
    # Match the leading part (proto://hostname, or just hostname)
    (
        # ftp://, http://, or https:// leading part
        (ftp|https?|telnet|nntp)://(\w+(:\w+)?@)?[-\w]+(\.\w[-\w]*)+
      |
        (mailto:)?[-\+\w]+\@[-\w]+(\.\w[-\w]*)+
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
         /?
         # The rest are heuristics for what seems to work well
         [^.!,?;:"'<>()\[\]{}\s\x7F-\xFF]*
         (?:
            [.!,?;:]+  [^.!,?;:"'<>()\[\]{}\s\x7F-\xFF]+ #'"
         )*
    )?
}x;

my $blocktags = qr{
  <
   (( /? ( h[1-6]
         | p
         | pre
         | div
         | table
         | t[rdh]
         | [ou]l
         | li
         | block(?:quote|code)
         )
      [ >]
    )
   | !--
   )
}x;

sub textile {
    my $str = shift;
    my $self = shift;

    if ((ref $str) && ($str->isa('Text::Textile'))) {
        # OOP technique used so swap params...
        ($self, $str) = ($str, $self);
    } else {
        if (!$self) {
            $self = new Text::Textile;
        }
    }

    my %macros = ('bq' => 'blockquote');
    my @repl;

    # strip out extra newline characters. we're only matching for \n herein
    $str =~ tr!\cM!!d;

    # preserve contents of the '==', 'pre', 'blockcode' sections
    $str =~ s!(^|\n\n)==(.+?)==($|\n\n)!$1."\n\n"._repl(\@repl, $self->format_block($2))."\n\n".$3!ges;

    $str =~ s|(<!--.+?-->)|_repl(\@repl, $1)|ges;

    my $pre_start = scalar(@repl);
    $str =~ s|(<pre(?: [^>]*)?>)(.+?)(</pre>)|"\n\n"._repl(\@repl, $1.$self->encode_html($2, 1).$3)."\n\n"|ges;
    # fix code tags within pre blocks we just saved.
    for (my $i = $pre_start; $i < scalar(@repl); $i++) {
        $repl[$i] =~ s|(&lt;/?code.*?&gt;)|$self->decode_html($1)|ges;
    }

    $str =~ s|(<code(?: [^>]+)?>)(.+?)(</code>)|_repl(\@repl, $1.$self->encode_html($2, 1).$3)|ges;

    $str =~ s|(<blockcode(?: [^>]+)?>)(.+?)(</blockcode>)|"\n\n"._repl(\@repl, $1.$self->encode_html($2, 1).$3)."\n\n"|ges;

    $str =~ s!(<blockquote(?: [^>]+)?>)(.+?)(</blockquote>)!"\n\n"._repl(\@repl, $1.$self->format_paragraph($2).$3)."\n\n"!ges;

    $str =~ s!(<(p|h[1-6])(?: [^>]+)?>)(.+?)(</\2>)!"\n\n"._repl(\@repl, $1.$self->format_paragraph($3).$4)."\n\n"!ges;

    # split up text into paragraph blocks
    my @para = split /\n{2,}/, $str;
    my ($block, $class, $sticky, $cite, @lines);

    my $out = '';

    foreach my $para (@para) {
        #$para =~ s/(^\s+|\s+$)//g;

        my $id;
        $block = undef unless $sticky;
        $class = undef unless $sticky;
        $cite = undef unless $sticky;
        $sticky++ if $sticky;

        my @lines;
        my $buffer;
        if ($para =~ m/^(h[1-6]|p|bq|bc)(\(([^\(\)]+)\))?(\.\.?)(:(\d+|$urlre))? /g) {
            if ($sticky) {
                if ($block eq 'bc') {
                    # close our blockcode section
                    $out =~ s/\n\n$//;
                    $out .= $self->{blockcode_close}."\n\n";
                } elsif ($block eq 'bq') {
                    $out =~ s/\n\n$//;
                    $out .= '</blockquote>'."\n\n";
                }
                $sticky = 0;
            }
            # block macros: h[1-6](class)., bq(class)., bc(class)., p(class).
            $block = $1;
            if ($4 eq '..') {
              $sticky = 1;
            } else {
              $sticky = 0;
              $cite = undef;
              $class = undef;
            }
            $class = $3 if defined $3;
            $cite = $5;
            if ((defined $class) && ($class =~ m/^([^#]+?)?(#(.*))?$/)) {
                $class = $1;
                $id = $3;
            }
            $cite =~ s/^:// if defined $cite;
            $para = substr($para, pos($para));
        } elsif ($para =~ m|^<textile#(\d+)>$|) {
            my $num = $1;
            if ($repl[$num-1] =~ m/$blocktags/) {
                $buffer = $repl[$num-1];
            }
        } elsif ($para =~ m/^(\((.+?)\))?[\*\#](\(([^\)]+?)\))? /) {
            # '*', '#' prefix means a list
            $buffer = $self->format_list($para);
        } elsif ($para =~ m/^(table(\((.+?)\))?\. +)?(\((.+?)\))?\|/) {
            # handle wiki-style tables
            $buffer = $self->format_table($para);
        }
        if (defined $buffer) {
            $out .= $buffer;
            next;
        }
        @lines = split /\n/, $para;
        next unless @lines;

        $block ||= 'p';

        $buffer = '';
        my $pre = '';
        my $post = '';

        if ($block eq 'bc') {
            if ($sticky <= 1) {
                $pre .= $self->{blockcode_open};
                $pre =~ s/>$//s;
                $pre .= qq{ class="$class"} if $class;
                $pre .= qq{ id="$id"} if $id;
                $pre .= qq{ cite="} . $self->format_url($cite) . '"' if defined $cite;
                $pre .= '>';
            }
            $buffer .= $self->encode_html_basic($para, 1);
            if ($sticky == 0) {
                $post .= $self->{blockcode_close}."\n\n";
            } else {
                $post .= "\n\n";
            }
            $out .= $pre . $buffer . $post;
            next;
        } elsif ($block eq 'bq') {
            if ($sticky <= 1) {
                $pre .= '<blockquote';
                $pre .= qq{ class="$class"} if defined $class;
                $pre .= qq{ id="$id"} if defined $id;
                $pre .= qq{ cite="} . $self->format_url($cite) . '"' if defined $cite;
                $pre .= '>';
            }
            $pre .= '<p>';
        } else {
            $pre .= '<' . ($macros{$block} || $block);
            $pre .= qq{ class="$class"} if $class;
            $pre .= qq{ id="$id"} if $id;
            $pre .= qq{ cite="} . $self->format_url($cite) . '"' if defined $cite;
            $pre .= '>';
        }

        #if ($para =~ m/$blocktags/) {
        #    $buffer = $para;
        #} else {
        #    for (my $i = 0; $i <= $#lines; $i++) {
        #        my $line = $lines[$i];
        #        chomp $line;
        #        $buffer .= $line;
        #        $buffer .= '<br />' . "\n" if $i < $#lines;
        #    }
        #}
        #$buffer = $self->format_paragraph($buffer);

        $buffer = $self->format_paragraph($para);

        if ($block eq 'bq') {
            $post .= '</p>' if $buffer !~ m/<p[ >]/;
            if ($sticky == 0) {
                $post .= '</blockquote>';
            }
        } else {
            $post .= '</' . $block . '>';
        }

        if ($buffer =~ m/$blocktags/) {
          $buffer =~ s/^\n\n//s;
          $out .= $buffer;
        } else {
          $out .= $pre . $buffer . $post;
        }

        $out .= "\n\n";
    }

    $out =~ s/\n\n$//;

    if ($sticky) {
        if ($block eq 'bc') {
            # close our blockcode section
            $out .= $self->{blockcode_close} . "\n\n";
        } elsif ($block eq 'bq') {
            $out .= '</blockquote>' . "\n\n";
        }
    }

    # cleanup-- restore preserved blocks
    my $i = 0;
    $i++, $out =~ s|<textile#$i>|$_| foreach @repl;

    $out;
}

sub format_paragraph {
    my $self = shift;
    my ($buffer) = @_;

    my @repl;
    $buffer =~ s!==(.+?)==!_repl(\@repl, $self->format_block($1, 1))!ges;

    my $tokens;
    if ($buffer =~ m/</) {  # optimization -- no point in tokenizing if we
                            # have no tags to tokenize
        $tokens = _tokenize($buffer);
    } else {
        $tokens = [['text', $buffer]];
    }
    my $result = '';
    foreach my $token (@$tokens) {
        my $text = $token->[1];
        if ($token->[0] eq 'tag') {
            $text =~ s/&(?!amp;)/&amp;/g;
            $result .= $text;
        } else {
            if ($text =~ m/[^A-Za-z0-9\s\.:]/) {
                $text = $self->format_inline($text);
            }
            if ($result !~ m/$blocktags/) {
                if ($text =~ m/\n/) {
                    if ($self->{line_open}) {
                        $text =~ s/^/$self->{line_open}/gm;
                        $text =~ s/(\n|$)/$self->{line_close}$1/gs;
                    } else {
                        $text =~ s/(\n)/$self->{line_close}$1/gs;
                    }
                }
            }
            $result .= $text;
        }
    }

    my $i = 0;
    $i++, $result =~ s|<textile\#$i>|$_|s foreach @repl;

    $result;
}

{
my @qtags = (['**', 'b',      '\*\*'],
             ['__', 'i',      '__'],
             ['??', 'cite',   '\?\?'],
             ['*',  'strong', '\*(?!\*)'],
             ['_',  'em',     '_(?!_)'],
             ['-',  'del',    '(?<!\-)\-(?!\-)'],
             ['+',  'ins',    '(?<!\+)\+(?!\+)'],
             ['^',  'sup',    '\^'],
             ['~',  'sub',    '\~']);

my $punct = qr{(?:[\!"#\$%&'()\*\+,\-\./:;<=>\?@\[\\\]\^_`{\|}\~])};

sub format_inline {
    my $self = shift;
    my ($text) = @_;

    my @repl;

    $text =~ s!(^|\s)@(\|([A-Za-z0-9]+)\|)?(.+?)@($punct{0,2})(\s|$)!$1._repl(\@repl, $self->format_code($4, $3)).$5.$6!gem;

    $text = $self->encode_html($text);
    $text =~ s!&lt;textile#(\d+)&gt;!<textile#$1>!g;
    $text =~ s!&amp;quot;!&#34;!g;
    $text =~ s!&amp;(([a-z]+|#\d+);)!&$1!g;
    $text =~ s!&quot;!"!g; #"

    # These create markup with entities. Do first and 'save' result for later:
    # "text":url -> hyperlink
    $text =~ s!(^|\s)"(\(([^"\(\)]+)\))?([^"]+?)(\([^\(]*\))?":(\d+|$urlre)!$1._repl(\@repl, $self->format_link($4,$self->encode_html_basic($5),$6,$3))!ge;

    # !blah (alt)! -> image
    $text =~ s!(^|\s|>)\!(\([A-Za-z0-9_\-\#]+\))?([^\s\(\!]*)((\([^\)]+\)|[^\!]+)?)\!(:(\d+|$urlre))?!$1._repl(\@repl, $self->format_image($3,$4,$6,$2))!gem;

    # (tm) -> &trade;
    $text =~ s|[\(\[]TM[\)\]]|&trade;|gi;
    # (c) -> &copy;
    $text =~ s|[\(\[]C[\)\]]|&copy;|gi;
    # (r) -> &reg;
    $text =~ s|[\(\[]R[\)\]]|<sup>&reg;</sup>|gi;

    my $redo = $text =~ m/[\*_\?\-\+\^\~]/;
    while ($redo) {
        # simple replacements...
        $redo = 0;
        foreach my $tag (@qtags) {
            my ($f, $r, $qf) = @$tag;
            if ($text =~ s:(^|[\s>'"])$qf(?=\S)(.+?)(?<=\S)$qf([\s<"']|$)?:$self->format_tag($r, $f, $1, $2, $3):gem) { # "'
                $redo = 1;
            }
        }
    }

    # ABC(Aye Bee Cee) -> acronym
    $text =~ s|\b([A-Z][A-Z0-9]+?)\b(?:[(]([^)]*)[)])|_repl(\@repl,qq{<acronym title="}.$self->encode_html_basic($2).qq{">$1</acronym>})|ge;

    # ABC -> 'capped' span
    $text =~ s/(^|[^"][>\s])([A-Z](?:[A-Z0-9\.,' ]|\&amp;){2,})([^a-z0-9]|$)/$1._repl(\@repl, qq{<span class="caps">$2<\/span>}).$3/gem;

    # nxn -> n&times;n
    $text =~ s|(\d+['"]?) ?x ?(\d)|$1&times;$2|g; #"'

    #$text =~ s!<(ins|del)>\[(\d{1,2}/\d{1,2}/\d{2,4}( \d{1,2}:\d\d(:\d\d)?)?)\]!$self->format_datetime($1, $2, $3, $4)!ges;

    # translate these encodings to the Unicode equivalents:
    $text =~ s/&#133;/&#8230;/g;
    $text =~ s/&#145;/&#8216;/g;
    $text =~ s/&#146;/&#8217;/g;
    $text =~ s/&#147;/&#8220;/g;
    $text =~ s/&#148;/&#8221;/g;
    $text =~ s/&#150;/&#8211;/g;
    $text =~ s/&#151;/&#8212;/g;

    $text = $self->apply_text_filters($text) if @{$self->{text_filters}};

    # Restore replacements done earlier:
    my $i = 0;
    $i++, $text =~ s|<textile\#$i>|$_|s foreach @repl;

    $text;
}
}

sub format_code {
    my $self = shift;
    my ($code, $lang) = @_;
    $code = $self->encode_html($code, 1);
    my $tag = '<code';
    $tag .= " language=\"$lang\"" if defined $lang;
    $tag . '>' . $code . '</code>';
}

#sub format_datetime {
#    my $self = shift;
#    my ($tag, $date, $hourmin, $sec) = @_;
#
#    my $tag = '<' . $tag;
#    if (defined $date) {
#    }
#    if (defined $hourmin) {
#        if (defined $sec) {
#        }
#    }
#    $tag . '>';
#}

sub apply_text_filters {
    my $self = shift;
    my ($text) = @_;
    my $filters = $self->text_filters;
    return $text unless (ref $filters) eq 'ARRAY';

    my $param = $self->filter_param;
    foreach my $filter (@$filters) {
        if ((ref $filter) eq 'CODE') {
            $text = $filter->($text, $param);
        }
    }
    $text;
}

sub apply_named_filters {
    my $self = shift;
    my ($text, $list) = @_;
    my $filters = $self->named_filters;
    return $text unless (ref $filters) eq 'HASH';

    my $param = $self->filter_param;
    foreach my $filter (@$list) {
        next unless exists $filters->{$filter};
        if ((ref $filters->{$filter}) eq 'CODE') {
            $text = $filters->{$filter}->($text, $param);
        }
    }
    $text;
}

sub format_tag {
    my $self = shift;
    my ($tag, $marker, $pre, $text, @rest) = @_;
    if (($text =~ m/^\s/) || ($text =~ m/\s$/)) {
        return $pre.$marker.$text.$marker.(join '', @rest);
    }
    my $res = '';
    $res .= $pre if defined $pre;
    $res .= '<'.$tag.'>';
    $res .= $text;
    $res .= '</'.$tag.'>';
    foreach (@rest) {
        $res .= $_ if defined $_;
    }
    $res;
}

{
    my $Have_Entities = eval 'use HTML::Entities; 1' ? 1 : 0;

    sub encode_html {
        my $self = shift;
        my($html, $can_double_encode) = @_;
        return '' unless defined $html;
        return $html unless $html =~ m/[^\w\s]/;
        if ($Have_Entities && $self->{char_encoding}) {
            $html = HTML::Entities::encode_entities($html);
        } else {
            $self->encode_html_basic($html, $can_double_encode);
        }
        $html;
    }

    sub decode_html {
        my $self = shift;
        my ($html) = @_;
        $html =~ s!&quot;!"!g;
        $html =~ s!&amp;!&!g;
        $html =~ s!&lt;!<!g;
        $html =~ s!&gt;!>!g;
        $html;
    }

    sub encode_html_basic {
        my $self = shift;
        my($html, $can_double_encode) = @_;
        return '' unless defined $html;
        $html =~ tr!\cM!!d;
        return $html unless $html =~ m/[^\w\s]/;
        if ($can_double_encode) {
            $html =~ s!&!&amp;!g;
        } else {
            ## Encode any & not followed by something that looks like
            ## an entity, numeric or otherwise.
            $html =~ s/&(?!#?[xX]?(?:[0-9a-fA-F]+|\w{1,8});)/&amp;/g;
        }
        $html =~ s!"!&quot;!g;
        $html =~ s!<!&lt;!g;
        $html =~ s!>!&gt;!g;
        $html;
    }

}

{
    my $Have_ImageSize = eval 'use Image::Size; 1' ? 1 : 0;

    sub image_size {
        my $self = shift;
        my ($file) = @_;
        if ($Have_ImageSize) {
            if (-f $file) {
                return Image::Size::imgsize($file);
            } else {
                if (my $docroot = $self->docroot) {
                    my $fullpath = File::Spec->catfile($docroot, $file);
                    if (-f $fullpath) {
                        return Image::Size::imgsize($fullpath);
                    }
                }
            }
        }
        undef;
    }
}

sub format_list {
    my $self = shift;
    my ($str) = @_;

    my %list_tags = ('*' => 'ul', '#' => 'ol');

    my @lines = split /\n/, $str;

    my @stack;
    my $last_depth = 0;
    my $item = '';
    my $out = '';
    foreach my $line (@lines) {
        if ($line =~ m/^(\((.+?)\))?([\#\*]+)(\((.+?)\))? (.+)$/) {
            if ($item ne '') {
                if ($item =~ m/\n/) {
                    if ($self->{line_open}) {
                        $item =~ s/(<li[^>]*>|^)/$1$self->{line_open}/gm;
                        $item =~ s/(\n|$)/$self->{line_close}$1/gs;
                    } else {
                        $item =~ s/(\n)/$self->{line_close}$1/gs;
                    }
                }
                $out .= $item;
                $item = '';
            }
            my ($blockid, $itemid);
            my $type = substr($3, 0, 1);
            my $depth = length($3);
            my $blockclass = $2;
            my $itemclass = $5;
            $line = $6;

            if ((defined $blockclass) &&
                ($blockclass =~ m/^([^#]+?)?(#(.*))?$/)) {
                $blockclass = $1;
                $blockid = $3;
            }
            if ((defined $itemclass) &&
                ($itemclass =~ m/^([^#]+?)?(#(.*))?$/)) {
                $itemclass = $1;
                $itemid = $3;
            }
            if ($depth > $last_depth) {
                for (my $j = $last_depth; $j < $depth; $j++) {
                    $out .= "\n<$list_tags{$type}";
                    push @stack, $type;
                    if ($blockclass) {
                        $out .= " class=\"$blockclass\"";
                        undef $blockclass;
                    }
                    if ($blockid) {
                        $out .= " id=\"$blockid\"";
                        undef $blockid;
                    }
                    $out .= ">\n<li";
                    if ($itemclass) {
                        $out .= " class=\"$itemclass\"";
                        undef $itemclass;
                    }
                    if ($itemid) {
                        $out .= " id=\"$itemid\"";
                        undef $itemid;
                    }
                    $out .= ">";
                }
            } elsif ($depth < $last_depth) {
                for (my $j = $depth; $j < $last_depth; $j++) {
                    $out .= "</li>\n" if $j == $depth;
                    my $type = pop @stack;
                    $out .= "</$list_tags{$type}>\n";
                    $out .= "</li>\n";
                }
                if ($depth) {
                    $out .= '<li';
                    if (defined $itemclass) {
                        $out .= " class=\"$itemclass\"";
                        undef $itemclass;
                    }
                    if (defined $itemid) {
                        $out .= " id=\"$itemid\"";
                        undef $itemid;
                    }
                    $out .= ">";
                }
            } else {
                $out .= "</li>\n<li";
                if (defined $itemclass) {
                    $out .= " class=\"$itemclass\"";
                    undef $itemclass;
                }
                if (defined $itemid) {
                    $out .= " id=\"$itemid\"";
                    undef $itemid;
                }
                $out .= ">";
            }
            $last_depth = $depth;
        }
        $item .= "\n" if $item ne '';
        $item .= $self->format_paragraph($line);
    }

    if ($item =~ m/\n/) {
        if ($self->{line_open}) {
            $item =~ s/(<li[^>]*>|^)/$1$self->{line_open}/gm;
            $item =~ s/(\n|$)/$self->{line_close}$1/gs;
        } else {
            $item =~ s/(\n)/$self->{line_close}$1/gs;
        }
    }
    $out .= $item;

    for (my $j = 1; $j <= $last_depth; $j++) {
        $out .= '</li>' if $j == 1;
        my $type = pop @stack;
        $out .= "\n".'</'.$list_tags{$type}.'>'."\n";
        $out .= '</li>' if $j != $last_depth;
    }

    $out."\n";
}

sub format_block {
    my $self = shift;
    my ($str, $inline) = @_;
    my ($filters) = $str =~ m/^(\|(?:(?:[a-z0-9_\-]+)\|)+)/;
    if ($filters) {
        my $filtreg = quotemeta($filters);
        $str =~ s/^$filtreg//;
        $filters =~ s/^\|//;
        $filters =~ s/\|$//;
        my @filters = split /\|/, $filters;
        $str = $self->apply_named_filters($str, \@filters);
        my $count = scalar(@filters);
        if ($str =~ s!(<p>){$count}!$1!gs) {
            $str =~ s!(</p>){$count}!$1!gs;
            $str =~ s!(<br( /)?>){$count}!$1!gs;
        }
    }
    if ($inline) {
        # strip off opening para, closing para, since we're
        # operating within an inline block
        $str =~ s/^\s*<p[^>]*>//;
        $str =~ s/<\/p>\s*$//;
    }
    $str;
}

sub format_link {
    my $self = shift;
    my ($text, $title, $url, $class) = @_;
    if (!defined $url || $url eq '') {
        $title = '' unless defined $title;
        $text = '' unless defined $title;
        return qq{"$text$title":};
    }
    $text =~ s/ +$//;
    $text = $self->format_paragraph($text);
    $url = $self->format_url($url);
    my $tag = qq{<a href="$url"};
    if ($class && ($class =~ m/^([^#]+?)?(#(.*))?$/)) {
        $tag .= qq{ class="$1"} if $1;
        $tag .= qq{ id="$3"} if $3;
    }
    if (defined $title) {
        $title =~ s/^\s?\(//;
        $title =~ s/\)$//;
        $tag .= qq{ title="$title"} if length($title);
    }
    $tag .= qq{>$text</a>};
    $tag;
}

sub format_url {
    my $self = shift;
    my ($url) = @_;
    if ($url =~ m/^(mailto:)?([-\+\w]+\@[-\w]+(\.\w[-\w]*)+)$/) {
        $url = 'mailto:'.$self->mail_encode($2);
    }
    if ($url !~ m!^(/|\./|\.\./)!) {
        $url = "http://$url" if $url !~ m!^(https?|ftp|mailto|nntp|telnet)!;
    }
    $url =~ s/&(?!amp;)/&amp;/g;
    $url;
}

sub mail_encode {
    my $self = shift;
    my ($addr) = @_;
    # granted, this is simple, but it gives off warm fuzzies
    $addr =~ s/([^\$])/uc sprintf("%%%02x",ord($1))/eg;
    $addr;
}

sub format_image {
    my $self = shift;
    my ($src, $extra, $link, $class) = @_;
    #print "<!-- src = $src; extra = $extra; link = $link; class = $class -->";
    return '!!' if length($src) == 0;
    my $tag  = qq{<img src="$src"};
    if ($class && ($class =~ m/\(([^#]+?)?(#(.*))?\)/)) {
        $tag .= qq{ class="$1"} if $1;
        $tag .= qq{ id="$3"} if $3;
    }
    my ($pctw, $pcth, $w, $h, $alt);
    if ($extra) {
        ($alt) = $extra =~ m/\(([^\)]+)\)/;
        $extra =~ s/\([^\)]+\)//;
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
    }
    $alt = '' unless defined $alt;
    $tag .= ' alt="' . $self->encode_html_basic($alt) . '"';
    if ($w && $h) {
        $tag .= qq{ height="$h" width="$w"};
    } else {
        my ($w, $h) = $self->image_size($src);
        if ($w && $h) {
            if ($pctw || $pcth) {
                $w = int($w * $pctw / 100);
                $h = int($h * $pcth / 100);
            }
            $tag .= qq{ height="$h" width="$w"};
        }
    }
    if ($self->{flavor} =~ m/xhtml/) {
        $tag .= ' />';
    } else {
        $tag .= '>';
    }
    if ($link) {
        $link =~ s/^://;
        $link = $self->format_url($link);
        $tag = '<a href="'.$link.'">'.$tag.'</a>';
    }
    $tag;
}

sub format_table {
    my $self = shift;
    my ($str) = @_;

    my @rows = split /\n/, $str;
    my $col_count = 0;
    foreach my $row (@rows) {
        my $cnt = $row =~ m/\|/;
        $col_count ||= $cnt;
        # ignore block if columns aren't even.
        return $str if $cnt != $col_count;
    }
    my ($tableclass, $tableid);
    if ($rows[0] =~ m/^(table(\(([^#]+?)?(#(.*))?\))?\.\s*)/) {
        $tableclass = $3;
        $tableid = $5;
        $rows[0] = substr($rows[0], length($1));
    }
    my $out = '';
    my (@colalign);
    foreach my $row (@rows) {
        my @cols = split /\|/, $row.' ';
        my $span = 0;
        my $row_out = '';
        my ($rowclass, $rowid);
        if ($cols[0] =~ m/\(([^#]+?)?(#(.*))?\)/) {
            $rowclass = $1;
            $rowid = $3;
        }
        for (my $c = $#cols-1; $c > 0; $c--) {
            my ($colclass, $colid, $header);
            my $colalign = $colalign[$c];
            my $col = $cols[$c];
            my $attrs = '';
            if ($col =~ m/^(([_^<>]{0,2})(\(([^#]+?)?(#(.*))?\)))/) {
                $colclass = $4;
                $colid = $6;
                $attrs .= $2 if $2;
                $col = substr($col, length($1));
            }
            if ($col =~ m/^([_^<>]{1,2}) /) {
                $attrs .= $1;
                $col = substr($col, length($1));
            }
            if (length($attrs)) {
                $header = 1 if $attrs =~ m/_/;
                if ($attrs =~ m/</) {
                    $colalign = 'left';
                } elsif ($attrs =~ m/\^/) {
                    $colalign = 'center';
                } elsif ($attrs =~ m/>/) {
                    $colalign = 'right';
                }
                $colalign[$c] = $colalign if $header;
                $col = substr($col, 1);
            }
            $col =~ s/^\s+//; $col =~ s/\s+$//;
            if (length($col)) {
                my $col_out;
                if ($header) {
                    $col_out = q{<th};
                } else {
                    $col_out = q{<td};
                }
                $col_out .= qq{ align="$colalign"} if defined $colalign;
                $col_out .= qq{ class="$colclass"} if $colclass;
                $col_out .= qq{ id="$colid"} if $colid;
                $col_out .= qq{ colspan="}.($span+1).'"' if $span;
                $col_out .= '>' . $self->format_paragraph($col);
                if ($header) {
                    $col_out .= '</th>';
                } else {
                    $col_out .= '</td>';
                }
                $row_out = $col_out . $row_out;
                $span = 0 if $span;
            } else {
                $span++;
            }
        }
        $row_out = qq{<td colspan="$span"></td>$row_out} if $span;
        $out .= qq{<tr};
        $out .= qq{ class="$rowclass"} if $rowclass;
        $out .= qq{ id="$rowid"} if $rowid;
        $out .= qq{>$row_out</tr>\n};
    }

    my $table = '';
    $table .= qq{<table};
    $table .= qq{ class="$tableclass"} if $tableclass;
    $table .= qq{ id="$tableid"} if $tableid;
    $table .= qq{ cellspacing="0"} if $tableclass || $tableid;
    $table .= qq{>$out</table>};
    $table;
}

sub _repl {
    push @{$_[0]}, $_[1];
    '<textile#'.(scalar(@{$_[0]})).'>';
}

sub _tokenize {
    my ($str) = @_;

    my $pos = 0;
    my $len = length $str;
    my @tokens;

    while ($str =~ m/(<[^>]*>)/gs) {
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

1;
__END__

=head1 NAME

Text::Textile

=head1 SYNOPSIS

  use Text::Textile qw(textile);
  my $text = <<EOT;
  h1. Heading

  A _simple_ demonstration of Textile markup.

  * One
  * Two
  * Three

  "More information":http://www.textism.com/tools/textile is available.
  EOT

  # procedural usage
  my $html = textile($text);
  print $html;

  # OOP usage
  my $textile = new Text::Textile;
  $html = $textile->process($text);
  print $html;

=head1 ABSTRACT

Text::Textile is a Perl-based implementation of Dean Allen's Textile
syntax. Textile is shorthand for doing common formatting tasks.

=head1 METHODS

=over 4

=item * new

Instantiates a new Text::Textile object.

=item * process( $str )

Alternative method for invoking textile().

=item * flavor( $flavor )

Assigns the HTML flavor of output from Text::Textile. Currently
these are the valid choices: html, xhtml (behaves like 'xhtml1'),
xhtml1, xhtml2.

=item * charset( $charset )

Assigns the character set targetted for publication.
At this time, Text::Textile only changes it's behavior
if the 'utf-8' character set is assigned.

=item * docroot( $path )

Physical file path to root of document files. This path
is utilized when images are referenced and size calculations
are needed (the Image::Size module is used to read the image
dimensions).

=item char_encoding( $encode )

Assigns the character encoding logical flag. If character
encoding is enabled, the HTML::Entities package is used to
encode special characters. If character encoding is disabled,
only <, >, " and & are encoded to HTML entities.

=item * filter_param( $data )

Stores a parameter that may be passed to any filter.

=item * named_filters( \%filters )

Optional %filters parameter assigns the list of named filters
to make available for Text::Textile to use. Returns a hash
reference of the currently assigned filters.

=item * text_filters( \@filters )

Optional @filters parameter assigns the textual filters for
Text::Textile to use. Returns an array reference of the
currently assigned text filters.

=item * textile( $str )

Can be called either procedurally or as a method. Transforms
$str using Textile markup rules.

=item * format_paragraph( $str )

Processes a single paragraph.

=item * format_inline( $str )

Processes an inline element (plaintext) for Textile syntax.

=item * apply_text_filters( $str )

Applies all the textual filters to $str.

=item * apply_named_filters( $str, \@list )

Applies all the filters identified in @list to $str.

=item * format_tag( $tag, $pre, $text, @rest )

Returns a constructed tag using the pieces given.

=item * format_list( $str )

Takes a Textile formatted list (numeric or bulleted) and
returns the markup for it.

=item * format_code( $code, $lang )

Processes '@...@' type blocks (code snippets).

=item * format_block( $str )

Processes '==xxxxx==' type blocks for filters.

=item * format_link( $text, $title, $url )

Takes the Textile link attributes and transforms them into
a hyperlink.

=item * format_url( $url )

Takes the given $url and transforms it appropriately.

=item * mail_encode( $email )

Encodes the email address in $email for 'mailto:' links.

=item * format_image( $src, $extra, $url, $class )

Returns markup for the given image. $src is the location of
the image, $extra contains the optional height/width and/or
alt text. $url is an optional hyperlink for the image. $class
holds the optional CSS class attribute.

=item * image_size( $src )

Returns the size for the image identified in $src.

=item * format_table( $str )

Takes a Wiki-ish string of data and transforms it into a full
table.

=item * _repl( \@arr, $str )

An internal routine that takes a string and appends it to an array.
It returns a marker that is used later to restore the preserved
string.

=item * _tokenize( $str )

An internal routine responsible for breaking up a string into
individual tag and plaintext elements.

=back

=head1 SYNTAX

The formatting options of Textile are simple to understand, but
difficult to master.

Textile looks at things in terms of paragraphs and lines.

=head1 LICENSE

Please see the file LICENSE that was included with this module.

=head1 AUTHOR & COPYRIGHT

Text::Textile was written by Brad Choate, L<brad@bradchoate.com>, and converted
to a CPAN module by Tom Insam, L<tom@jerakeen.org>.
It is an adaptation of Textile, developed by Dean Allen of Textism.com.

=cut
