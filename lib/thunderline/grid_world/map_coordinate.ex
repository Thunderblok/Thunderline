defmodule Thunderline.GridWorld.MapCoordinate do
  @moduledoc """
  Represents a coordinate in the Thunderline Grid World system that maps to real-world GPS coordinates.

  The coordinate system supports:
  - GPS coordinates (lat/lng) for real-world positioning
  - 3D voxel coordinates (x/y/z) for virtual grid space
  - Timestamp and tick tracking for synchronization
  - Region and zone identification for PAC coordination
  """

  use Ash.Resource,
    domain: Thunderline.Domain,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "map_coordinates"
    repo Thunderline.Repo
  end

  attributes do
    uuid_primary_key :id

    # Real-world GPS coordinates
    attribute :latitude, :decimal, allow_nil?: false
    attribute :longitude, :decimal, allow_nil?: false
    attribute :altitude, :decimal, default: 0.0

    # Virtual 3D grid coordinates
    attribute :grid_x, :integer, allow_nil?: false
    attribute :grid_y, :integer, allow_nil?: false
    attribute :grid_z, :integer, default: 0

    # Temporal tracking
    attribute :tick_id, :integer, allow_nil?: false
    attribute :timestamp, :utc_datetime, allow_nil?: false, default: &DateTime.utc_now/0

    # Spatial organization
    attribute :region_id, :string, allow_nil?: false
    attribute :zone_id, :string, allow_nil?: false

    # Google Maps integration
    attribute :place_id, :string
    attribute :google_maps_uri, :string
    attribute :formatted_address, :string

    # Metadata
    attribute :pac_id, :string
    attribute :coordinate_type, :string, default: "pac_position"
    attribute :accuracy_meters, :decimal
    attribute :metadata, :map, default: %{}

    timestamps()
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [
        :latitude, :longitude, :altitude,
        :grid_x, :grid_y, :grid_z,
        :tick_id, :region_id, :zone_id,
        :place_id, :google_maps_uri, :formatted_address,
        :pac_id, :coordinate_type, :accuracy_meters, :metadata
      ]
    end

    update :update do
      accept [
        :latitude, :longitude, :altitude,
        :grid_x, :grid_y, :grid_z,
        :tick_id, :place_id, :google_maps_uri,
        :formatted_address, :accuracy_meters, :metadata
      ]
    end

    read :by_region do
      argument :region_id, :string, allow_nil?: false
      filter expr(region_id == ^arg(:region_id))
    end

    read :by_zone do
      argument :zone_id, :string, allow_nil?: false
      filter expr(zone_id == ^arg(:zone_id))
    end

    read :by_pac do
      argument :pac_id, :string, allow_nil?: false
      filter expr(pac_id == ^arg(:pac_id))
    end

    read :by_tick do
      argument :tick_id, :integer, allow_nil?: false
      filter expr(tick_id == ^arg(:tick_id))
    end

    read :recent_coordinates do
      argument :since, :utc_datetime, allow_nil?: false
      filter expr(timestamp >= ^arg(:since))
    end
  end
  code_interface do
    domain Thunderline.Domain

    define :create
    define :update
    define :read
    define :by_region, args: [:region_id]
    define :by_zone, args: [:zone_id]
    define :by_pac, args: [:pac_id]
    define :by_tick, args: [:tick_id]
    define :recent_coordinates, args: [:since]
  end

  @doc """
  Converts GPS coordinates to normalized grid coordinates.
  This creates a unified coordinate system where:
  - Grid coordinates are integers
  - Each grid cell represents approximately 1 meter
  - Origin (0,0) is configurable per region
  """
  def gps_to_grid(latitude, longitude, region_origin \\ {0.0, 0.0}) do
    {origin_lat, origin_lng} = region_origin

    # Approximate conversion: 1 degree latitude ≈ 111,000 meters
    # 1 degree longitude ≈ 111,000 * cos(latitude) meters
    lat_meters = (latitude - origin_lat) * 111_000
    lng_meters = (longitude - origin_lng) * 111_000 * :math.cos(:math.pi() * latitude / 180)

    {round(lng_meters), round(lat_meters)}
  end

  @doc """
  Converts grid coordinates back to GPS coordinates.
  """
  def grid_to_gps(grid_x, grid_y, region_origin \\ {0.0, 0.0}) do
    {origin_lat, origin_lng} = region_origin

    # Convert back from meters to degrees
    lat_offset = grid_y / 111_000
    lng_offset = grid_x / (111_000 * :math.cos(:math.pi() * origin_lat / 180))

    {origin_lat + lat_offset, origin_lng + lng_offset}
  end

  @doc """
  Calculates distance between two coordinates in meters.
  """  # def distance_meters(%__MODULE__{} = coord1, %__MODULE__{} = coord2) do
  #   haversine_distance(coord1.latitude, coord1.longitude, coord2.latitude, coord2.longitude)
  # end

  def distance_meters(coord1, coord2) do
    haversine_distance(coord1.latitude, coord1.longitude, coord2.latitude, coord2.longitude)
  end

  defp haversine_distance(lat1, lng1, lat2, lng2) do
    # Haversine formula for calculating distance between two GPS points
    r = 6371000  # Earth's radius in meters

    lat1_rad = lat1 * :math.pi() / 180
    lat2_rad = lat2 * :math.pi() / 180
    delta_lat = (lat2 - lat1) * :math.pi() / 180
    delta_lng = (lng2 - lng1) * :math.pi() / 180

    a = :math.sin(delta_lat / 2) * :math.sin(delta_lat / 2) +
        :math.cos(lat1_rad) * :math.cos(lat2_rad) *
        :math.sin(delta_lng / 2) * :math.sin(delta_lng / 2)

    c = 2 * :math.atan2(:math.sqrt(a), :math.sqrt(1 - a))

    r * c
  end
end
