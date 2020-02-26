#!/usr/bin/perl

#     Author Daniel M German <dmg@turingmachine.org>
#
#     This program is free software: you can redistribute it and/or modify
#     it under the terms of the GNU General Public License as published by
#     the Free Software Foundation, either version 3 of the License, or
#     (at your option) any later version.

#     This program is distributed in the hope that it will be useful,
#     but WITHOUT ANY WARRANTY; without even the implied warranty of
#     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#     GNU General Public License for more details.

#     You should have received a copy of the GNU General Public License
#     along with this program.  If not, see <https://www.gnu.org/licenses/>.

use utf8;
use DBI;
use strict;
use Encode qw( decode_utf8 encode);

use Getopt::Long qw(GetOptions);
use Pod::Usage qw(pod2usage);

use File::Basename qw(dirname);
use Cwd  qw(abs_path);
use lib dirname abs_path $0;

use anki;


my $QUERY_REVIEW_CARDS_AUDIO_HEAD = <<END;
with
     toreview as (
        select datetime(id/1000.0, 'unixepoch', 'localtime')  as revdatestr,
        id/1000 as revdate, -- convert from miliseconds to seconds
        id,
        cid, ease, ivl, lastivl, factor, time, type
         from revlog
     )
  select modelname, revdatestr, fld_get(notes.flds,findex) as audio, ease, r.ivl, lastivl, r.factor, time, r.type
    from toreview r
      left join cards on (cards.id = cid)
      left join notes on (notes.id = cards.nid)
      left join modelinfo using (mid)
      left join modelfields using (mid)
  where fname = ?
END

my $COMMON_ORDER_BY = "order by r.id desc, modelname, audio";


my $QUERY_REVIEW_CARDS_by_N = <<END;
$QUERY_REVIEW_CARDS_AUDIO_HEAD
$COMMON_ORDER_BY
        limit ?
        ;
END

my $QUERY_REVIEW_CARDS_by_DATE = <<END;
$QUERY_REVIEW_CARDS_AUDIO_HEAD
    and r.revdatestr > ?
$COMMON_ORDER_BY
;
END






my $printModels = 0;
my $printFields = 0;
my $createTables = 0;

my $debug = 0;

my $printAudio = 1;

my $numberCards = 20;

my $fieldName = 'Audio';
my $help;
my $date;
my $verbose;



GetOptions ("print-models" => \$printModels,
            "print-fields"   => \$printFields,
            "create-tables" => \$createTables,
            "field=s" => \$fieldName,
            "cards=i" => \$numberCards,
            "date=s" => \$date,
            "help|?" => \$help,
            "verbose"  => \$verbose)   # flag
        or pod2usage(1);

pod2usage(-verbose=>3) if $help;

my $collection = shift;

pod2usage(2) if (not defined $collection );

my @models = @ARGV;


if (not -f $collection) {
    print STDERR "Collection [$collection] does not exist\n\n";
    pod2usage(2);
}


Open_Anki($collection) or die "Unable to open collection [$collection]";

Create_Tables($createTables);

if ($printModels) {
    Print_Models(@models);
}

if ($printFields) {
    Print_Models_Fields(@models);
}

exit 0 if ($printFields or $printModels );

Print_Reviews($numberCards, $date, $fieldName, @models);



exit 0; # this is the end...

#------------------------------

sub Print_Reviews {
    my ($numberCards, $date, $field, @models) = @_;

    my $query;
    my @parms;

    if (defined ($date)) {
        $query = $QUERY_REVIEW_CARDS_by_DATE;
        @parms = ($date);
    } else {
        $query = $QUERY_REVIEW_CARDS_by_N;
        @parms = ($numberCards);
    }

    $query = Extend_Where_Model($query, "order by ",
                                'and',
                                 @models);

    print "$query\n" if $debug;

    Do_Complex_Query_With_Header($query, $fieldName, @parms);

}







#-----------------------------------------------------------------
#----------------  Documentation / Usage / Help ------------------
=head1 NAME

        anki_reviews - listing log of reviews done in anki

=head1 SYNOPSIS

anki_list_audio <options*> collectionFile [modelnames]

            Use --help for more info.

=head1 DESCRIPTION

This program can be used to extract information of anki cards that are due in
the future.

It prints a tab-delimited lists of the next cards to review, including a
specific field (by default Audio).

Note that only cards that contain the specific field are printed.

    collectionFile: corresponds to the anki collection file (collection.anki2 )

    modelnames: narrow the output to a list of models. See --print_models below
        for a list of models in the collection

=head1 EXAMPLES

  1)

See options below for more features.

=head1 OPTIONS

=over 8

=item B<--help>

Print a brief help message and exits.

=item B<--field=name>

By default print the "Audio" field of a card. This option allows to override that behaviour.

=item B<--print-models>

Prints the names of all models in the collection. Note that cards of different models can be in the same deck.
Therefore, a model can span multiple decks. The model defines the fields a card can have.

=item B<--print-fields>

Prints the field names for the models in the collection

=item B<--create-tables>

We create two temporary tables in the collection that contain the information about the models and their fields.
If you want them to be permanent, enable this option.

=item B<--cards=n>

By default, it print all the cards due in the future.
If you specify a number, it will print the n cards (order by their due date--sooner first).

=item B<--date=string>

Print reviews since date given (format yyyy-mm-dd hh:mm:ss) during the last n days.
It is possible to specify part of the date (e.g. since feb of 2019: "2019-02")

Overrides --cards option.

=item B<--verbose>

Print some debug information.

=back

=cut
