# 19-collector.ex — Elixir comes from work rather than from your tree, so
# there is no file count to quote.
#
# What to look at: atoms and keyword keys, module attributes (`@doc`, `@spec`
# and the plain constants), sigils, the pipe, binary patterns, and `def`,
# `case` and `with`, which are macros here and keywords everywhere else.
#
# Standard library only. One file holds several modules, which Elixir allows.

defmodule Preview.Severity do
  @moduledoc """
  Ranks how loudly a record should be reported.

  Levels run from `:debug` to `:fatal`.
  """

  @type t :: :debug | :info | :warn | :fatal

  @levels [debug: 0, info: 1, warn: 2, fatal: 3]
  @loud_from Keyword.fetch!(@levels, :warn)

  defguard is_level(term) when term in [:debug, :info, :warn, :fatal]

  @doc "Numeric weight of a level."
  @spec weight(t()) :: non_neg_integer()
  def weight(level) when is_level(level), do: Keyword.fetch!(@levels, level)

  @spec loud?(t()) :: boolean()
  def loud?(level), do: weight(level) >= @loud_from

  @doc """
  Parses the one-letter or full name of a level.

      iex> Preview.Severity.parse("W")
      {:ok, :warn}
  """
  @spec parse(String.t() | nil) :: {:ok, t()} | {:error, {:unknown_level, String.t()}}
  def parse(nil), do: {:ok, :info}

  def parse(code) when is_binary(code) do
    case code |> String.trim() |> String.upcase() do
      <<"D", _rest::binary>> -> {:ok, :debug}
      "I" <> _rest -> {:ok, :info}
      upper when upper in ~w(W WARN WARNING) -> {:ok, :warn}
      "FATAL" -> {:ok, :fatal}
      other -> {:error, {:unknown_level, other}}
    end
  end
end

defprotocol Preview.Describe do
  @doc "A short human-readable form of the value."
  @spec describe(t()) :: String.t()
  def describe(value)
end

defmodule Preview.Record do
  @moduledoc "One structured log line."

  import Preview.Severity, only: [is_level: 1]

  alias Preview.Severity

  @default_tags ~w(preview leo-dark)

  @enforce_keys [:id, :message]
  defstruct [:id, :message, level: :info, tags: @default_tags, meta: %{}]

  @type t :: %__MODULE__{
          id: String.t(),
          message: String.t(),
          level: Severity.t(),
          tags: [String.t()],
          meta: %{optional(atom()) => term()}
        }

  @doc """
  Builds a record, validating the id.

  ## Examples

      iex> Preview.Record.new("rec_0a1b2c3d", "boot")
      {:ok, %Preview.Record{id: "rec_0a1b2c3d", message: "boot"}}
  """
  @spec new(String.t(), String.t(), keyword()) :: {:ok, t()} | {:error, term()}
  def new(id, message, opts \\ []) when is_binary(id) and is_binary(message) do
    with :ok <- validate_id(id),
         {:ok, level} <- fetch_level(opts) do
      meta = Map.new(opts[:meta] || [])
      {:ok, struct!(__MODULE__, id: id, message: message, level: level, meta: meta)}
    else
      {:error, _reason} = error -> error
      _other -> {:error, :invalid}
    end
  end

  @spec new!(String.t(), String.t(), keyword()) :: t()
  def new!(id, message, opts \\ []) do
    case new(id, message, opts) do
      {:ok, record} -> record
      {:error, reason} -> raise ArgumentError, "invalid record: #{inspect(reason)}"
    end
  end

  @spec summary(t()) :: String.t()
  def summary(%__MODULE__{level: level, message: message, meta: meta}) do
    pairs = meta |> Enum.sort() |> Enum.map_join(" ", fn {key, value} -> "#{key}=#{value}" end)
    label = level |> Atom.to_string() |> String.upcase() |> String.pad_trailing(5)

    if pairs == "", do: "#{label} · #{message}", else: "#{label} · #{message} · #{pairs}"
  end

  defp validate_id(id) do
    if id =~ ~r/^rec_[0-9a-f]{8}$/i, do: :ok, else: {:error, {:malformed_id, id}}
  end

  defp fetch_level(opts) do
    case Keyword.get(opts, :level, :info) do
      level when is_level(level) -> {:ok, level}
      code when is_binary(code) -> Severity.parse(code)
      other -> {:error, {:unknown_level, other}}
    end
  end
end

defimpl Preview.Describe, for: Preview.Record do
  def describe(record), do: "record(#{record.level}: #{record.message})"
end

defimpl Preview.Describe, for: [Integer, Float] do
  def describe(number) when is_integer(number), do: Integer.to_string(number)
  def describe(number), do: :erlang.float_to_binary(number, decimals: 3)
end

defimpl Preview.Describe, for: List do
  def describe([]), do: "list[]"
  def describe([first | rest]), do: "list[#{inspect(first)} + #{length(rest)} more]"
end

defmodule Preview.CollectError do
  defexception [:reason, message: "collect failed"]

  @impl true
  def exception(reason) when is_atom(reason) do
    %__MODULE__{reason: reason, message: "collect failed: #{reason}"}
  end
end

defmodule Preview.Sink do
  @moduledoc "Anything that can swallow a batch of records."

  @callback write(batch :: [Preview.Record.t()]) :: {:ok, non_neg_integer()} | {:error, term()}
  @callback name() :: String.t()
  @optional_callbacks name: 0

  defmacro __using__(opts) do
    name = Keyword.get(opts, :name, "anonymous")

    quote do
      @behaviour unquote(__MODULE__)

      @impl unquote(__MODULE__)
      def name, do: unquote(name)

      defoverridable name: 0
    end
  end
end

defmodule Preview.MemorySink do
  @moduledoc "A sink that keeps the newest records in memory."

  use GenServer
  use Preview.Sink, name: "memory"

  require Logger

  alias Preview.{CollectError, Record}

  @max_retries 3
  @flush_interval 250
  @banner_width 0x4A
  @golden_ratio 1.618_033_988_749
  @flags 0b1010_1101
  @mode 0o755
  @epsilon 1.0e-3
  @marker ?→
  @started ~D[2026-01-01]

  # ── Client ────────────────────────────────────────────────────────────────

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name, __MODULE__))
  end

  @impl Preview.Sink
  def write(batch), do: write(__MODULE__, batch)

  @spec write(GenServer.server(), [Record.t()]) :: {:ok, non_neg_integer()} | {:error, term()}
  def write(_server, []), do: {:error, :empty_batch}
  def write(server, batch) when is_list(batch), do: GenServer.call(server, {:write, batch}, 5_000)

  # ── Server ────────────────────────────────────────────────────────────────

  @impl GenServer
  def init(opts) do
    capacity = Keyword.get(opts, :capacity, 16)
    Process.send_after(self(), :flush, @flush_interval)
    {:ok, %{seen: [], capacity: capacity, closed?: false}}
  end

  @impl GenServer
  def handle_call({:write, _batch}, _from, %{closed?: true} = state) do
    {:reply, {:error, :closed}, state}
  end

  def handle_call({:write, batch}, _from, %{seen: seen, capacity: capacity} = state) do
    kept = Enum.take(batch ++ seen, capacity)
    {:reply, {:ok, length(kept)}, %{state | seen: kept}}
  end

  def handle_call(:drain, _from, state) do
    {:reply, Enum.reverse(state.seen), %{state | seen: []}}
  end

  @impl GenServer
  def handle_cast(:close, state), do: {:noreply, %{state | closed?: true}}

  @impl GenServer
  def handle_info(:flush, %{seen: seen} = state) do
    Logger.debug(fn -> "flush: #{length(seen)} buffered" end)
    Process.send_after(self(), :flush, @flush_interval)
    {:noreply, state}
  end

  def handle_info(_message, state), do: {:noreply, state}

  # ── Helpers ───────────────────────────────────────────────────────────────

  @doc "Runs `fun` until it succeeds or the budget runs out."
  @spec retry((pos_integer() -> result), pos_integer(), pos_integer()) :: result | {:error, term()}
        when result: var
  def retry(fun, times \\ @max_retries, attempt \\ 1) when is_function(fun, 1) do
    Process.put(:preview_attempt, attempt)

    try do
      fun.(attempt)
    rescue
      error in [CollectError, ArgumentError] ->
        Logger.warning("attempt #{attempt}/#{times} failed: #{Exception.message(error)}")
        if attempt < times, do: retry(fun, times, attempt + 1), else: reraise(error, __STACKTRACE__)
    catch
      :exit, reason -> {:error, {:exit, reason}}
      :throw, value -> {:error, {:thrown, value}}
    after
      Process.delete(:preview_attempt)
    end
  end

  @doc "Splits a wire frame: one tag byte, a 16-bit length, then the payload."
  @spec decode(binary()) :: {:ok, {atom(), binary()}, binary()} | :more
  def decode(<<tag::8, size::unsigned-big-integer-size(16), payload::binary-size(size), rest::binary>>) do
    kind =
      cond do
        tag == ?R -> :record
        tag in ?0..?9 -> :digit
        true -> :unknown
      end

    {:ok, {kind, payload}, rest}
  end

  def decode(_partial), do: :more

  @spec partition([Record.t()]) :: {loud :: [Record.t()], quiet :: [Record.t()]}
  def partition(records), do: Enum.split_with(records, &Preview.Severity.loud?(&1.level))

  @doc false
  def literals do
    %{
      atoms: [:ok, :"quoted atom", Preview.Record, nil, true, false],
      words: ~w(alpha beta gamma)a,
      charlist: ~c"abc",
      raw: ~S(no #{interpolation} \n here),
      escapes: "tab\there \x41 · \u{1F600}",
      numbers: {1_000_000, 0x4A, 0b1010, 0o755, 1.0e-3, ?a, -42},
      "quoted key": @started,
      time: ~T[12:30:00],
      nested: [a: 1, b: [c: 2]]
    }
  end

  # ── Entry point ───────────────────────────────────────────────────────────

  @doc false
  def run(args \\ System.argv()) do
    {:ok, sink} = start_link(capacity: 8)

    records =
      for {level, index} <- Enum.with_index([:debug, :info, :warn, :fatal]), into: [] do
        id = "rec_" <> String.pad_leading(Integer.to_string(index, 16), 8, "0")
        Record.new!(id, "event #{index} ready", level: level, meta: [attempt: index, ok: rem(index, 2) == 0])
      end

    written =
      retry(fn
        1 when args != [] ->
          raise CollectError, :unexpected_arguments

        _attempt ->
          {:ok, count} = write(records)
          count
      end)

    {loud, quiet} = partition(records)
    expected = length(records)

    case written do
      ^expected -> :ok
      other -> Logger.error("wrote #{inspect(other)}, expected #{expected}")
    end

    IO.puts(String.duplicate("─", @banner_width))
    IO.puts("#{String.pad_trailing("sink:", 12)}#{name()}")
    IO.puts("#{String.pad_trailing("written:", 12)}#{inspect(written)} of #{expected}")
    IO.puts("#{String.pad_trailing("loud/quiet:", 12)}#{length(loud)}/#{length(quiet)}")
    IO.puts(~s("#{<<@marker::utf8>>}" stays quoted, phi #{Float.round(@golden_ratio, 6)}))
    IO.puts("flags: #{@flags} mode: #{@mode} epsilon: #{@epsilon} since: #{@started}")

    records
    |> Enum.sort_by(&{Preview.Severity.weight(&1.level), &1.message})
    |> Enum.map(&Record.summary/1)
    |> Enum.each(&IO.puts("  " <> &1))

    [42, 1.618, records, hd(records)]
    |> Stream.map(&Preview.Describe.describe/1)
    |> Stream.with_index(1)
    |> Enum.each(fn {line, n} -> IO.puts("  #{n}. #{line}") end)

    frame = <<?R, 5::16, "hello", 0xFF, 0x00>>
    {:ok, {:record, "hello"}, <<255, 0>>} = decode(frame)

    parent = self()
    ref = make_ref()
    spawn(fn -> send(parent, {ref, :pong, Enum.to_list(1..10//3)}) end)

    receive do
      {^ref, :pong, steps} -> IO.inspect(steps, label: "steps", charlists: :as_lists)
    after
      1_000 -> IO.puts(:stderr, "timed out")
    end

    drained = GenServer.call(sink, :drain)
    :ok = GenServer.cast(sink, :close)
    {:error, :closed} = write(records)
    :ok = GenServer.stop(sink)

    report = """
    Preview report
      records:  #{length(drained)}
      loud:     #{length(loud)}
      escaped:  \#{not interpolated}, and \\t stays a backslash and a t
    """

    IO.write(report)
    if drained != [], do: :ok, else: {:error, :nothing_written}
  end
end
