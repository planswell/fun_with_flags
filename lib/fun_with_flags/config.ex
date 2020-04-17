defmodule FunWithFlags.Config do
  @moduledoc false
  @default_redis_config [
    host: "localhost",
    port: 6379,
    database: 0,
  ]

  @default_cache_config [
    enabled: true,
    ttl: 900 # in seconds, 15 minutes
  ]

  @default_notifications_config [
    enabled: true,
    adapter: FunWithFlags.Notifications.Redis
  ]

  @default_persistence_config [
    adapter: FunWithFlags.Store.Persistent.Redis,
    repo: FunWithFlags.NullEctoRepo,
  ]

  def redis_config do
    case Application.get_env(:fun_with_flags, :redis, []) do
      uri  when is_binary(uri) ->
        uri
      opts when is_list(opts) ->
        if Keyword.get(opts, :url) do
          opts
          |> default_redis_options([])
          |> Keyword.pop(:url)
        else
          default_redis_options(opts, @default_redis_config)
        end

      {:system, var} when is_binary(var) ->
        System.get_env(var)
    end
  end

  defp default_redis_options(config, defaults) do
    config
    |> Keyword.merge(defaults)
    |> add_aws_config()
    |> Keyword.delete(:aws)
  end

  defp deep_merge(_key, value1, value2) do
    if Keyword.keyword?(value1) and Keyword.keyword?(value2) do
      Keyword.merge(value1, value2, &deep_merge/3)
    else
      value2
    end
  end

  defp add_aws_config(config) do
    if Keyword.get(config, :aws) && Keyword.get(config, :ssl) do
      aws_ssl_config = [socket_opts: [customize_hostname_check: [match_fun: :public_key.pkix_verify_hostname_match_fun(:https)]]]
      config
      |> Keyword.merge(aws_ssl_config, &deep_merge/3)
    else
      config
    end
  end


  def cache? do
    Keyword.get(ets_cache_config(), :enabled)
  end


  def cache_ttl do
    Keyword.get(ets_cache_config(), :ttl)
  end


  defp ets_cache_config do
    Keyword.merge(
      @default_cache_config,
      Application.get_env(:fun_with_flags, :cache, [])
    )
  end


  # If we're not using the cache, then don't bother with
  # the 2-level logic in the default Store module.
  #
  def store_module do
    if __MODULE__.cache? do
      FunWithFlags.Store
    else
      FunWithFlags.SimpleStore
    end
  end


  defp persistence_config do
    Keyword.merge(
      @default_persistence_config,
      Application.get_env(:fun_with_flags, :persistence, [])
    )
  end

  # Defaults to FunWithFlags.Store.Persistent.Redis
  #
  def persistence_adapter do
    Keyword.get(persistence_config(), :adapter)
  end


  def ecto_repo do
    Keyword.get(persistence_config(), :repo)
  end


  def persist_in_ecto? do
    persistence_adapter() == FunWithFlags.Store.Persistent.Ecto
  end


  defp notifications_config do
    Keyword.merge(
      @default_notifications_config,
      Application.get_env(:fun_with_flags, :cache_bust_notifications, [])
    )
  end


  # Defaults to FunWithFlags.Notifications.Redis
  #
  def notifications_adapter do
    Keyword.get(notifications_config(), :adapter)
  end


  def phoenix_pubsub? do
    notifications_adapter() == FunWithFlags.Notifications.PhoenixPubSub
  end


  def pubsub_client do
    Keyword.get(notifications_config(), :client)
  end


  # Should the application emir cache busting/syncing notifications?
  # Defaults to false if we are not using a cache and if there is no
  # notifications adapter configured. Else, it defaults to true.
  #
  def change_notifications_enabled? do
    cache?() &&
    notifications_adapter() &&
    Keyword.get(notifications_config(), :enabled)
  end


  # I can't use Kernel.make_ref/0 because this needs to be
  # serializable to a string and sent via Redis.
  # Erlang References lose a lot of "uniqueness" when
  # represented as binaries.
  #
  def build_unique_id do
    (:crypto.strong_rand_bytes(10) <> inspect(:os.timestamp()))
    |> Base.url_encode64(padding: false)
  end
end
