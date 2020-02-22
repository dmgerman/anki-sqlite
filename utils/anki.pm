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

my $sep = chr(31);
my $dbh;

my $DROP_MODEL = <<END;
drop table if exists modelinfo;
END


my $CREATE_MODEL = <<END;
CREATE TABLE modelinfo as
  SELECT value as modelname,
  substr(substr(r.fullkey, 3), 0, instr(substr(r.fullkey, 3), '.'))  as mid,
     r.fullkey from col, json_tree(col.models) as r
  where r.key = 'name' and (r.fullkey regexp '^\\\$\\.[0-9]+\\.name\$')
;
END

my $DROP_DECK = <<END;
drop table if exists deckinfo;
END

my $CREATE_DECK = <<END;
create table deckinfo as
        SELECT value as deckname,
        substr(substr(r.fullkey, 3), 0, instr(substr(r.fullkey, 3), '.'))  as did,
        r.fullkey from col, json_tree(col.decks) as r
        where r.key = 'name';
END


my $DROP_MODEL_FIELDS = <<END;
drop table if exists modelfields;
END

my $CREATE_MODEL_FIELDS = <<END;
create table modelfields as
  with t as (
           select r.*, substr(r.fullkey, instr(r.fullkey, "[")+1) as fullkey2,
           substr(r.fullkey, 3, instr(r.fullkey, ".flds[")-3) as mid
           from col, json_tree(col.models) as r where r.key = 'name' and r.fullkey regexp 'flds\\\[[0-9]+\\\]'
            and fullkey2 <> fullkey -- make sure that there was a [ in fullkey
                                                                  ),

           r as (select *, substr(fullkey2, 0, length(fullkey2)-5) as findex from t)

                  select mid, value as fname, findex, fullkey from r;
END


my $QUERY_MODELS_INFO = <<END;
select modelname, count(distinct notes.id) as notes, count(*) cards, sum(queue>0) reviewed
  from modelinfo join notes using (mid)
    join cards on (notes.id = cards.nid)
  group by modelname;
END

my $QUERY_MODELS_FIELDS = <<END;
select modelname, fname, findex
   from modelinfo left join modelfields using (mid)
order by modelname, cast(findex as int);
END

my $QUERY_DECKS_INFO = <<END;
select deckname, modelname, count(distinct notes.id) as notes, count(distinct cards.id) as  cards, count(distinct revlog.cid) as nreviewed, count(revlog.cid) as nreviews
  from modelinfo join notes using (mid)
    join cards on (notes.id = cards.nid) join deckinfo using (did)
    left join revlog on (revlog.cid = cards.id)
  group by modelname, deckname
order by deckname, modelname
;
END


sub Count_Fields  {
    my ($st) = @_;

    my $i = 0;
    for my $j (0..length($st)-1) {
        $i++ if substr($st, $j,1) eq $sep;
    }

    return $i+1;
}

sub Replace_Field{
    my ($st, $i, $newVal) = @_;

    my $n = Count_Fields($st);
    if ($i == 0) {
        die "modifying first field not supported";
    }
    if ($i >= $n  or $i < 0) {
        die "trying to update field [$i][$n] that does not exist";
        return;
    } else {
        # remember, it must be terminated by a separator..
        my @f = split(/$sep/, $st);
        for my $j (0..$n-1) {
            $f[$j] = "" if not defined($f[$j]);
        }
        $f[$i] = $newVal;

        my $newFields = join($sep, @f);
        die "something went wrong in replace field" if ($n != Count_Fields($newFields));

        return $newFields;
    }
}

sub Get_Field {
    my ($st, $i) = @_;

    my $n = Count_Fields($st);
    if ($i >= $n ) {
        return;
    } else {
        my @f = split(/$sep/, $st);
        return $f[$i];
    }
}

sub Open_Anki {
    my ($database) = @_;

    if (not -f $database) {
        die "Collection does not exist [$database]";
    }

    my $driver   = "SQLite";
    my $dsn = "DBI:$driver:dbname=$database";
    my $userid = "";
    my $password = "";
    $dbh = DBI->connect($dsn, $userid, $password, { RaiseError => 1 , AutoCommit => 0})
            or die $DBI::errstr;


    Do_SQL('PRAGMA encoding = "UTF-8"; ');

    $dbh->sqlite_create_function( 'fld_count', 1, \&Count_Fields );
    $dbh->sqlite_create_function( 'fld_get', 2, \&Get_Field );
    $dbh->sqlite_create_function( 'fld_replace', 3, \&Replace_Field );

    return $dbh;
}

sub Do_Complex_Query {
    my ($query, @parms) = @_;
    my $q = $dbh->prepare($query);
    $q->execute(@parms);
    while (my @f = $q->fetchrow_array()) {
        print join("\t", @f ), "\n";
    }
    return ;
}

sub Do_Complex_Query_With_Header {
    my ($query, @parms) = @_;
    my $q = $dbh->prepare($query);
    $q->execute(@parms);
    my $fieldnames = $q->{NAME};
    print join("\t", @{$fieldnames}), "\n";
    while (my @f = $q->fetchrow_array()) {
        print join("\t", @f ), "\n";
    }
    return ;
}

sub Return_Complex_Query {
    my ($query, @parms) = @_;
    my $q = $dbh->prepare($query);
    $q->execute(@parms);
    my @result;
    while (my @f = $q->fetchrow_array()) {
        push(@result, \@f);
    }
    return @result;
}



sub Simple_Query {
    my ($query, @parms) = @_;
    my $q = $dbh->prepare($query);
    $q->execute(@parms);
    return $q->fetchrow();
}


sub Do_SQL {
    my ($st, @parms) = @_;
    my $stm = $dbh->prepare($st);
    $stm->execute(@parms);


}

sub Commit {
    $dbh -> commit();
}

sub Disconnect {
    $dbh -> disconnect();
}

sub Create_Model_Tables {
    my ($commit) = @_;

    Simple_Query($DROP_MODEL);
    Simple_Query($CREATE_MODEL);

    Simple_Query($DROP_MODEL_FIELDS);
    Simple_Query($CREATE_MODEL_FIELDS);

    my $count = Simple_Query("select count(*) from modelinfo");


    if ($commit ) {
        print STDERR "Creating model tables.\n";
        print STDERR "$count models found\n" ;
        Commit() ;
    }
}

sub Create_Deck_Tables {
    my ($commit) = @_;

    Do_SQL($DROP_DECK);
    Do_SQL($CREATE_DECK);

    my $count = Simple_Query("select count(*) from deckinfo");

    if ($commit ) {
        print STDERR "Creating deck tables.\n";
        print STDERR "$count decks found\n" ;
        Commit() ;
    }
}

sub Create_Tables {
    my ($commit) = @_;

    Create_Model_Tables($commit);
    Create_Deck_Tables($commit);
}




sub Print_Decks {
    my (@models) = @_;

    Do_Report($QUERY_DECKS_INFO, 'group by', 'where',
              @models);

}


sub Print_Models {
    my (@models) = @_;

    Do_Report($QUERY_MODELS_INFO, 'group by', 'where',
              @models);

}

sub Print_Models_Fields {
    my (@models) = @_;

    Do_Report($QUERY_MODELS_FIELDS, 'order by', 'where',
              @models);

}

#QUERY_MODELS_FIELDS_HEADER
#        $QUERY_MODELS_FIELDS;
sub Do_Report {
    my ($query, $whereLoc, $before, @models) = @_;


    # build the query with a where clause if necessary

    $query = Extend_Where_Model($query, $whereLoc, $before,
                                @models);

    Do_Complex_Query_With_Header($query);

}


sub Anki_Model_Id {
    my ($modelName) = @_;
    my $r = Simple_Query("select mid from modelinfo where modelname = ?", $modelName);
#    print "->[$r]\n";
    return $r;
}

sub Anki_Field_Id {
    my ($modelName, $fieldName) = @_;
    my $r = Simple_Query("select findex from modelinfo join modelfields using (mid)  where modelname = ? and fname = ?", $modelName, $fieldName);
#    print "->[$r]\n";
    return $r;
}



sub Extend_Where_Model {
    my ($query, $location, $before, @vals) = @_;

    if (scalar(@vals) > 0) {
        # build the query with a where clause

        my $exp = "'" . join("','", @vals). "'";
        #        print "$exp\n";

        #        print $query
        $query =~ s/$location/$before modelname IN ($exp) $location/;

    }
    return $query;

}





1;
