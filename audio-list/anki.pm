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


1;
