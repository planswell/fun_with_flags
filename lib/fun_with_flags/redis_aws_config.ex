defmodule FunWithFlags.RedisAWSConfig do
  @moduledoc """
    Parse options and tweak ssl configuration for ElasticCache
  """

  def add_config(config) do
    if Keyword.get(config, :aws) do
      aws_ssl_config = [socket_opts: [customize_hostname_check: [match_fun: :public_key.pkix_verify_hostname_match_fun(:https)]]]
      config
      |> Keyword.merge(aws_ssl_config, &deep_merge/3)
      |> Keyword.delete(:aws)
    else
      config
    end
  end

  defp deep_merge(_key, value1, value2) do
    if Keyword.keyword?(value1) and Keyword.keyword?(value2) do
      Keyword.merge(value1, value2, &deep_merge/3)
    else
      value2
    end
  end
end
