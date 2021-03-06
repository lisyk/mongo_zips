class Zip
  include ActiveModel::Model

  attr_accessor :id, :city, :state, :population

  def to_s
    "#{@id}: #{@city}, #{@state}, pop=#{@population}"
  end
  
  # tell Rails whether this instance is persisted
  def persisted?
    !@id.nil?
  end
  def created_at
    nil
  end
  def updated_at
    nil
  end

  # initialize for both Mongo and a Web hash
  def initialize(params={})
    #switch between both internal and external views of id and population
    @id=params[:_id].nil? ? params[:id] : params[:_id]
    @city=params[:city]
    @state=params[:state]
    @population=params[:pop].nil? ? params[:population] : params[:pop]
  end

  # convenience method for access to client in console
  def self.mongo_client
    Mongoid::Clients.default
  end

  # convenience method for access to zips collection
  def self.collection
    self.mongo_client['zips']
  end

  def self.paginate(params)
    Rails.logger.debug("paginate(#{params})")
    page=(params[:page] ||= 1).to_i
    limit=(params[:per_page] ||= 30).to_i
    offset=(page-1)*limit

    #get the associated page of Zips -- eagerly convert doc to Zip
    zips=[]
    all({}, {}, offset, limit).each do |doc|
      zips << Zip.new(doc)
    end

    #get a count of all documents in the collection
    total=all({}, {}, 0, 1).count

    WillPaginate::Collection.create(page, limit, total) do |pager|
      pager.replace(zips)
    end
  end

  def self.all(prototype={}, sort={:population=>1}, offset=0, limit=100)
    #map internal :population term to :pop document term
    tmp = {} #hash needs to stay in stable order provided
    sort.each {|k,v|
      k = k.to_sym==:population ? :pop : k.to_sym
      tmp[k] = v  if [:city, :state, :pop].include?(k)
    }
    sort=tmp

    #convert to keys and then eliminate any properties not of interest
    prototype=prototype.symbolize_keys.slice(:city, :state) if !prototype.nil?

    Rails.logger.debug {"getting all zips, prototype=#{prototype}, sort=#{sort}, offset=#{offset}, limit=#{limit}"}

    result=collection.find(prototype)
               .projection({_id:true, city:true, state:true, pop:true})
               .sort(sort)
               .skip(offset)
    result=result.limit(limit) if !limit.nil?

    return result
  end

  def self.find id
    Rails.logger.debug {"getting zip #{id}"}

    doc=collection.find(:_id=>id)
            .projection({_id:true, city:true, state:true, pop:true})
            .first
    return doc.nil? ? nil : Zip.new(doc)
  end

  def save
    Rails.logger.debug {"saving #{self}"}

    self.class.collection.insert_one(_id:@id, city:@city, state:@state, pop:@pop)
  end

  def update(updates)
    Rails.logger.debug {"updating #{self} with #{updates}"}

    # map internal :population term to :pop document term
    updates[:pop]=updates[:population]  if !updates[:population].nil?

    self.class.collection.find(_id:@id).update_one(:$set=>updates)
  end

  def destroy
    Rails.logger.debug {"destroying #{self}"}

    self.class.collection.find(_id:@id).delete_one
  end
end