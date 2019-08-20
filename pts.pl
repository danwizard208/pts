#!/usr/bin/perl

#TODO:
# 1. DONE
# 2. DONE
# 3. DONE
# 4. Add zsh/bash completion

use v5.10;
use strict;
use File::Spec;
use DateTime;
use DateTime::Duration;
use DateTime::Format::Strptime;

my $PTS_DIR = $ENV{PTS_DIR} || "$ENV{HOME}/.pts";
my $PTS_EXTENSION = "pts";
my $strp = DateTime::Format::Strptime->new(pattern => '%F', strict => 1);

my $command = shift;
if ($command eq "init")
{
    my $taskname = shift;
    unless ($taskname)
    {
        say "No task name given to init!";
        say "Usage is: pts init <task name> [frequency]";
        # Explain about task-name file name mapping?
        # Explain about frequency parsing?
        exit(1);
    }
    my $frequency = shift || "Daily";
    my $task = init_task($taskname, $frequency);
    write_task($task);
}
elsif ($command eq "reset")
{
    unless (@ARGV)
    {
        say "No task name given to reset!";
        say "Usage is: pts reset <task name>";
        exit(1);
    }
    while (@ARGV)
    {
        write_task(reset_task(parse_task(shift)));
    }
}
elsif ($command eq "tick")
{
    unless (@ARGV)
    {
        say "No task name given to tick!";
        say "Usage is: pts tick <task name>";
        exit(1);
    }
    while (@ARGV)
    {
        write_task(tick_task(parse_task(shift)));
    }
}
elsif ($command eq "dump")
{
    unless (@ARGV)
    {
        say "No task name given to dump!";
        say "Usage is: pts dump <task name>";
        exit(1);
    }
    while (@ARGV)
    {
        dump_task(parse_task(shift));
    }
}
elsif ($command eq "list")
{
    say filename_to_taskname($_) while <$PTS_DIR/*.$PTS_EXTENSION>;
}
elsif ($command eq "total")
{
    my $total = 0;
    $total += sum_task(parse_task(filename_to_taskname($_))) while <$PTS_DIR/*.$PTS_EXTENSION>;
    say "Total points: $total";
}
elsif ($command eq "expiring")
{
    my $duration = DateTime::Duration->new(days => shift || 0);
    while(<$PTS_DIR/*.$PTS_EXTENSION>)
    {
        my $task = parse_task(filename_to_taskname($_));
        my $freq_dur = frequency_as_dur($task->{frequency});
        my $expiry = $task->{last_date} + $freq_dur;
        if (DateTime->today(time_zone => 'local') + $duration >= $expiry)
        {
            # This includes already expired tasks
            say $task->{name};
        }
    }
}
else
{
    say "Unrecognized command: $command";
    say "Usage is: pts <command> [args]";
    say "where <command> is one of: init, reset, tick, dump, list, total, expiring";
    exit(1);
}


# Subs

# task "methods" (consider making the interface actually OO)
sub init_task
{
    my $taskname = shift;
    my $frequency = shift;
    return {
        frequency => $frequency,
        last_date => DateTime->today(time_zone => 'local'),
        chains => [[1]],
        name => "$taskname"
    };
}

sub parse_task
{
    my $name = shift;
    my $qualified_name = "$PTS_DIR/$name.$PTS_EXTENSION";
    die "$qualified_name does not exist or can't be read!" unless(-e -f -r $qualified_name);
    open TASK, $qualified_name;
    chomp (my $frequency_line = <TASK>);
    chomp (my $last_date_line = <TASK>);
    my $last_date = $strp->parse_datetime($last_date_line);
    my @chains = ();
    while (chomp(my $line = <TASK>))
    {
        push @chains, [split /\s+/, $line];
    }
    close TASK;
    return {
        frequency => $frequency_line,
        last_date => $last_date,
        chains => [@chains],
        name => $name
    };
}

sub tick_task
{
    my $task = shift;
    #TODO
    my $freq_dur = frequency_as_dur($task->{frequency});
    my $expiry = $task->{last_date} + $freq_dur;
    if (DateTime->today(time_zone => 'local') > $expiry)
    {
        push @{$task->{chains}}, [1];
    }
    else
    {
        my $last_chain_element = @{$task->{chains}[-1]}[-1];
        push @{$task->{chains}[-1]}, $last_chain_element+1;
    }
    $task->{last_date} = DateTime->today(time_zone => 'local');
    return $task;
}

sub reset_task
{
    my $task = shift;
    $task->{last_date} = DateTime->today(time_zone => 'local');
    return $task;
}

sub sum_task
{
    my $task = shift;
    my $sum = 0;
    foreach my $chain (@{$task->{chains}})
    {
        map { $sum += $_ } @$chain;
    }
    return $sum;
}

sub write_task
{
    my $task = shift;
    my $qualified_name = "$PTS_DIR/$task->{name}.$PTS_EXTENSION";
    open TASK, ">$qualified_name";
    say TASK $task->{frequency};
    say TASK $strp->format_datetime($task->{last_date});
    foreach my $chain (@{$task->{chains}})
    {
        say TASK join " ", @$chain;
    }
    close TASK;
}

sub dump_task
{
    my $task = shift;
    say "$task->{name} occurrs at frequency: $task->{frequency}.";
    my $formatted_date = $strp->format_datetime($task->{last_date});
    say "Last date completed was $formatted_date.";
    foreach my $chain (@{$task->{chains}})
    {
        my $sum = 0; map { $sum += $_ } @$chain;
        say "Chain of length @$chain with sum $sum";
    }
}

# "Translation" utilities

sub filename_to_taskname
{
    my(undef,undef,$file) = File::Spec->splitpath($_);
    $file =~ s/\.pts$//;
    return $file;
}

sub frequency_as_dur
{
    my $freq_string = shift;
    if ($freq_string =~ /^daily/i)
    {
        return DateTime::Duration->new(days => 1);
    }
    elsif ($freq_string =~ /^weekly/i)
    {
        return DateTime::Duration->new(days => 7);
    }
    elsif ($freq_string =~ /^(\d+)\s+days?/i)
    {
        return DateTime::Duration->new(days => $1);
    }
    elsif ($freq_string =~ /^(\d+)\s+weeks?/i)
    {
        return DateTime::Duration->new(days => $1 * 7);
    }
    else
    {
        #not implemented
        return DateTime::Duration->new();
    }
}
