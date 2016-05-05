#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = SleepCycle.rb -- PostRunner - Manage the data from your Garmin sport devices.
#
# Copyright (c) 2016 by Chris Schlaeger <cs@taskjuggler.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

module PostRunner

  # A SleepPhase is a segment of a sleep cycle. It captures the start and
  # end time as well as the kind of phase.
  class SleepPhase

    attr_reader :from_time, :to_time, :phase

    # Create a new sleep phase.
    # @param from_time [Time] Start time of the phase
    # @param to_time [Time] End time of the phase
    # @param phase [Symbol] The kind of phase [ :rem, :nrem1, :nrem2, :nrem3 ]
    def initialize(from_time, to_time, phase)
      @from_time = from_time
      @to_time = to_time
      @phase = phase
    end

    # Duration of the phase in seconds.
    # @return [Fixnum] duration
    def duration
      @to_time - @from_time
    end

  end

  # A sleep cycle consists of several sleep phases. This class is used to
  # gather and store the relevant data of a sleep cycle. Data is analzyed and
  # stored with a one minute granularity. Time values are stored as minutes
  # past the zero_idx_time.
  class SleepCycle

    attr_reader :total_seconds, :totals
    attr_accessor :start_idx, :end_idx,
                  :high_low_trans_idx, :low_high_trans_idx,
                  :prev_cycle, :next_cycle

    # Create a new SleepCycle record.
    # @param zero_idx_time [Time] This is the time of the 0-th minute. All
    #        time values are stored as minutes past this time.
    # @param start_idx [Fixnum] Time when the sleep cycle starts. We may start
    #        with an appromated value that gets fine tuned later on.
    # @param prev_cycle [SleepCycle] A reference to the preceding sleep cycle
    #        or nil if this is the first cycle of the analyzed period.
    def initialize(zero_idx_time, start_idx, prev_cycle = nil)
      @zero_idx_time = zero_idx_time
      @start_idx = start_idx
      # These values will be determined later.
      @end_idx = nil
      # Every sleep cycle has at most one high/low heart rate transition and
      # one low/high transition. These variables store the time of these
      # transitions or nil if the transition does not exist. Every cycle must
      # have at least one of these transitions to be a valid cycle.
      @high_low_trans_idx = @low_high_trans_idx = nil
      @prev_cycle = prev_cycle
      # Register this cycle as successor of the previous cycle.
      prev_cycle.next_cycle = self if prev_cycle
      @next_cycle = nil
      # Array holding the sleep phases of this cycle
      @phases = []
      # A hash with the total durations (in secods) of the various sleep
      # phases.
      @total_seconds = Hash.new(0)
    end

    # The start time of the cycle as Time object
    # @return [Time]
    def from_time
      idx_to_time(@start_idx)
    end

    # The end time of the cycle as Time object.
    # @return [Time]
    def to_time
      idx_to_time(@end_idx + 1)
    end

    # Remove this cycle from the cycle chain.
    def unlink
      @prev_cycle.next_cycle = @next_cycle if @prev_cycle
      @next_cycle.prev_cycle = @prev_cycle if @next_cycle
    end

    # Initially, we use the high/low heart rate transition to mark the end
    # of the cycle. But it's really the end of the REM phase that marks the
    # end of a sleep cycle. If we find a REM phase, we use its end to adjust
    # the sleep cycle boundaries.
    # @param phases [Array] List of symbols that describe the sleep phase at
    #        at the minute corresponding to the Array index.
    def adjust_cycle_boundaries(phases)
      end_of_rem_phase_idx = nil
      @start_idx.upto(@end_idx) do |i|
        end_of_rem_phase_idx = i if phases[i] == :rem
      end
      if end_of_rem_phase_idx
        # We have found a REM phase. Adjust the end_idx of this cycle
        # accordingly.
        @end_idx = end_of_rem_phase_idx
        if @next_cycle
          # If we have a successor phase, we also adjust the start.
          @next_cycle.start_idx = end_of_rem_phase_idx + 1
        end
      end
    end

    # Gather a list of SleepPhase objects that describe the sequence of sleep
    # phases in the provided Array.
    # @param phases [Array] List of symbols that describe the sleep phase at
    #        at the minute corresponding to the Array index.
    def detect_phases(phases)
      @phases = []
      current_phase = phases[0]
      current_phase_start = @start_idx

      @start_idx.upto(@end_idx) do |i|
        if (current_phase && current_phase != phases[i]) || i == @end_idx
          # We found a transition in the sequence. Create a SleepPhase object
          # that describes the prepvious segment and add it to the @phases
          # list.
          @phases << (p = SleepPhase.new(idx_to_time(current_phase_start),
                                         idx_to_time(i == @end_idx ? i + 1 : i),
                                         current_phase))
          # Add the duration of the phase to the corresponding sum in the
          # @total_seconds Hash.
          @total_seconds[current_phase] += p.duration

          # Update the variables that track the start and kind of the
          # currently read phase.
          current_phase_start = i
          current_phase = phases[i]
        end
      end
    end

    # Check if this cycle is really a sleep cycle or not. A sleep cycle must
    # have at least one deep sleep phase or must be part of a directly
    # attached series of cycles that contain a deep sleep phase.
    # @return [Boolean] True if not a sleep cycle, false otherwise.
    def is_wake_cycle?
      !has_deep_sleep_phase? && !has_leading_deep_sleep_phase? &&
        !has_trailing_deep_sleep_phase?
    end


    # Check if the cycle has a deep sleep phase.
    # @return [Boolean] True of one of the phases is NREM3 phase. False
    #         otherwise.
    def has_deep_sleep_phase?
      # A real deep sleep phase must be at least 10 minutes long.
      @phases.each do |p|
        return true if p.phase == :nrem3 && p.duration > 10 * 60
      end

      false
    end

    # Check if any of the previous cycles that are directly attached have a
    # deep sleep cycle.
    # @return [Boolean] True if it has a leading sleep cycle.
    def has_leading_deep_sleep_phase?
      return false if @prev_cycle.nil? || @start_idx != @prev_cycle.end_idx + 1

      @prev_cycle.has_deep_sleep_phase? ||
        @prev_cycle.has_leading_deep_sleep_phase?
    end

    # Check if any of the trailing cycles that are directly attached have a
    # deep sleep cycle.
    # @return [Boolean] True if it has a trailing sleep cycle.
    def has_trailing_deep_sleep_phase?
      return false if @next_cycle.nil? || @end_idx + 1 != @next_cycle.start_idx

      @next_cycle.has_deep_sleep_phase? ||
        @next_cycle.has_trailing_deep_sleep_phase?
    end

    private

    def idx_to_time(idx)
      return nil unless idx
      @zero_idx_time + 60 * idx
    end

  end

end
