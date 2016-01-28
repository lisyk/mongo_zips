json.array!(@zips) do |zip|
  json.extract! zip, :id, :id, :city, :state, :population
  json.url zip_url(zip, format: :json)
end
