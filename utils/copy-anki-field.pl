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

require "./anki.pm";


my $QUERY_NEXT_CARDS_AUDIO = <<END;
with toreviewraw as (
                   select id as cid, nid,
                      due as dueanki,
                     crt + due * (60 * 60 *24)  as duetimestamp,
                   *  from cards, (select crt from col)  where type = 2 and queue >= 0
                    ),
     toreview as (
        select datetime(duetimestamp, 'unixepoch', 'localtime') as duedatestr, *
         from toreviewraw
     )
  select modelname, duedatestr, duetimestamp, fld_get(notes.flds,findex) as audio, type, queue, due, ivl, factor, reps, lapses
    from toreview r
      left join notes on (notes.id = r.nid)
      left join modelinfo using (mid)
      left join modelfields using (mid)
  where fname = ?
order by duetimestamp, modelname, audio
limit ?
;
END



my $printModels = 0;
my $printFields = 0;
my $createTables = 0;

my $debug = 0;
my $dryRun = 0;


my $fieldName = 'Audio';
my $help;

my $verbose;

GetOptions ("print-models" => \$printModels,
            "print-fields"   => \$printFields,
            "create-tables" => \$createTables,
            "dry-run" => \$dryRun,
            "help|?" => \$help,
            "verbose"  => \$verbose)   # flag
        or pod2usage(1);

pod2usage(-verbose=>3) if $help;


my $collection = shift;
my $model = shift;
my $src = shift;
my $dst = shift;

pod2usage(2) if (not (defined $collection ));

Open_Anki($collection) or die "Unable to open collection [$collection]";

# always create the models first, To make sure that we are up-to-date
Create_Model_Tables( (not $dryRun) and ($createTables > 0 ));

my @models = ();

if ($model) {
    @models = ($model);
}

if ($printModels or $printFields) {

    Print_Models(@models) if $printModels;
    Print_Models_Fields(@models) if $printFields;

    exit 0 if not defined($src);

}

pod2usage(2) if (not (defined $collection  and
                      defined $model and
                      defined $src and
                      defined $dst));



if (not -f $collection) {
    print STDERR "Collection [$collection] does not exist\n\n";
    pod2usage(2);
}

print STDERR "Copying field [$src] to [$dst] in [$model]\n";

my $modelId = Anki_Model_Id($model) || pod2usage("Model [$model] does not exist");

my $dstId = Anki_Field_Id($model, $dst);
if (not defined $dstId) {
    pod2usage("Field [$dst] in Model [$model] does not exist");
}


if ($src ne "__ROW_NUMBER__") {
   my $srcId = Anki_Field_Id($model, $src);
   if (not defined $srcId) {
       pod2usage("Field [$src] in Model [$model] does not exist");
   }
   print STDERR "Copying field [$src] to [$dst] in [$model] mid [$modelId] from [$srcId] to [$dstId]\n";

   Do_SQL("update notes set flds = fld_replace(flds, ?, fld_get(flds, ?)) where mid = ?",
          $dstId, $srcId, $modelId);

} else {

    print STDERR "Using notes number instead of source field value\n";

# create table with noteid and row number, easier to do the update, and faster
    Do_SQL("create temp table rip as select id, row_number() over (order by id) as idx from notes where mid = ?",
           $modelId);
    Do_SQL("create index ripidx on rip(idx);");

    Do_SQL("update notes set flds = fld_replace(flds, ?, (select idx from rip where notes.id = rip.id)) where mid = ?",
           $dstId, $modelId);
}



Commit() if not $dryRun;

exit 0; # this is the end...

#------------------------------







#-----------------------------------------------------------------
#----------------  Documentation / Usage / Help ------------------
=head1 NAME

        anki_copy_fields - copy one field into another in all notes that share the same model

=head1 SYNOPSIS

anki_copy_fields <options*> collectionFile modelname sourceFieldName destinationFieldName

            Use --help for more info.

=head1 DESCRIPTION

    This program  copies the value of one field from one card to another for all cards in a given mode.

    It is also capable of replacing a field with the number of card in the model (not in the deck). In that case,
    use as the source field name __ROW_NUMBER__

=head1 EXAMPLES

  1) ...

See options below for more features.

=head1 OPTIONS

=over 8

=item B<--help>

Print a brief help message and exits.

=item B<--print-models>

Prints the names of all models in the collection. Note that cards of different models can be in the same deck.
Therefore, a model can span multiple decks. The model defines the fields a card can have.

=item B<--print-fields>

Prints the field names for the models in the collection

=item B<--create-tables>

We create two temporary tables in the collection that contain the information about the models and their fields.
If you want them to be permanent, enable this option.

=item B<--dry-run>

Do not actually do the copy. Simply report the number of fields copied.

=item B<--verbose>

Print some debug information.

=back

=cut
