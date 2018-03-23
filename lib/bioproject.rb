require 'open-uri'
require 'json'
require 'json/ld'
require 'rdf/turtle'

module JSON
  class << self
    def load_without_attr_symbol(data)
      load(data.gsub(/\n/,"").gsub('{"@','{"').gsub(', "@',', "'))
    end
  end
end

class PunkAPI
  class << self
    attr_accessor :endpoint_url
  end

  class BioProject
    def initialize(id)
      @id = id
    end

    def endpoint_path
      "http://#{PunkAPI.endpoint_url}/api/bioproject/#{@id}"
    end

    def data
      open(endpoint_path).read
    end

    def json
      #JSON.load_without_attr_symbol(data)
      JSON.load(data)
    end
  end
end

class LDSRA
  class << self
    def jsonld_to_turtle(jsonld, prefixes)
      tg = RDF::Graph.new << JSON::LD::API.toRdf(jsonld)
      tg.dump(:ttl, prefixes: prefixes)
    end
  end
end

class LDSRA
  class BioProject
    @@rdf_version = "0.1.0"

    def initialize(id)
      @id = id
      @json_raw = PunkAPI::BioProject.new(@id).json
    end
    attr_reader :json_raw

    def json
      {
        "submission" => json_submission,
        "project" => json_project,
        "projectLinks" => json_links,
      }
    end

    def json_submission
      submission = @json_raw["Package"]["Project"]["Submission"]
      {
        "submissionId" => submission["@submission_id"],
        "submitted" => submission["@submitted"],
        "lastUpdate" => submission["@last_update"],
        "description" => {
          "access" => submission["Description"]["Access"]["$"],
          "organization" => json_submission_organization,
        },
      }
    end

    def json_submission_organization
      org = @json_raw["Package"]["Project"]["Submission"]["Description"]["Organization"]
      # json can contain both a hash and an array of hashes, force them to be an array
      org_arr = org.class == Hash ? [org] : org
      org_arr.map do |o|
        {
          "name" => o["Name"]["$"],
          "abbreviation" => o["Name"]["@abbr"],
          "role" => o["@role"],
          "type" => o["@type"],
          "url" => o["@url"],
        }
      end
    rescue NoMethodError
      nil
    end

    def json_project
      project = @json_raw["Package"]["Project"]["Project"]
      {
        "projectDescription" => json_project_descr,
        "projectId" => json_project_id,
        # Not supporting ProjectType field
        # "ProjectType" => {},
      }
    end

    def json_project_descr
      p_desc = @json_raw["Package"]["Project"]["Project"]["ProjectDescr"]
      {
        "name" =>         p_desc["Name"]["$"],
        "title" =>        p_desc["Title"]["$"],
        "description" =>  p_desc["Description"]["$"],
        "externalLink" => json_project_descr_elink,
        "grant" =>        json_project_descr_grant,
        "publication" =>  json_project_descr_publication,
      }
    end

    def json_project_descr_elink
      elink = @json_raw["Package"]["Project"]["Project"]["ProjectDescr"]["ExternalLink"]
      elink_arr = elink.class == Hash ? [elink] : elink
      elink_arr.map do |el|
        {
          "URL" => el["URL"]["$"],
          "label" => el["@label"],
          "category" => el["@category"]
        }
      end
    rescue NoMethodError
      nil
    end

    def json_project_descr_grant
      grant = @json_raw["Package"]["Project"]["Project"]["ProjectDescr"]["Grant"]
      grant_arr = grant.class == Hash ? [grant] : grant
      grant_arr.map do |g|
        {
          "grantId" => g["@GrantId"],
          "agency" => {
            "name" => g["Agency"]["$"],
            "abbreviation" => g["Agency"]["@abbr"],
          }
        }
      end
    rescue NoMethodError
      nil
    end

    def json_project_descr_publication
      publication = @json_raw["Package"]["Project"]["Project"]["ProjectDescr"]["Publication"]
      publication_arr = publication.class == Hash ? [publication] : publication
      publication_arr.map do |pub|
        db_type = pub["DbType"]["$"]
        id      = pub["@id"]
        url = case db_type
              when "ePubmed"
                "http://identifiers.org/pubmed/" + id
              when "ePMC"
                "http://identifiers.org/pmc/" + id
              end
        {
          "URL" => url,
          "identifier" => id,
          "publicationDate" => pub["@date"],
          "status" => pub["@status"],
        }
      end
    rescue NoMethodError
      nil
    end

    def json_project_id
      p_id = @json_raw["Package"]["Project"]["Project"]["ProjectID"]
      {
        "archiveId" => {
          "accession" => p_id["ArchiveID"]["@accession"],
          "archive" => p_id["ArchiveID"]["@archive"],
          "id" => p_id["ArchiveID"]["@id"],
        }
      }
    end

    def json_links
      link = @json_raw["Package"]["Project"]["ProjectLinks"]["Link"]
      link_arr = link.class == Hash ? [link] : link
      link_arr.map do |l|
        if l.has_key?("Hierarchical")
          {
            "@type" => "biocow:BioProjectLink",
          }
        elsif l.has_key?("PeerProject")
          {
            "@type" => "biocow:BioProjectLink",
          }
        end
      end
    rescue NoMethodError
      nil
    end

    #
    # JSON-LD context
    #

    def jsonld
      {
        "@context" => bioproject_context,
        "URI" => bioproject_uri,
        "entry_type" => bioproject_entry_type,
        "identifier" => @id,
        "label" => "BioProject entry #{@id}",

        "Submission" => jsonld_submission,
        "Project" => jsonld_project,
        "ProjectLinks" => jsonld_links,
      }
    end

    def jsonld_submission
      if @json["Package"]["Project"]["Submission"]
        {
          "@context" => submission_context,
        }.merge(
          @json["Package"]["Project"]["Submission"]
        )
      else
        {}
      end
    end

    def jsonld_project
      if @json["Package"]["Project"]["Project"]
        {
          "@context" => project_context,
        }.merge(
          @json["Package"]["Project"]["Project"]
        )
      else
        {}
      end
    end

    def jsonld_links
      if @json["Package"]["Project"]["ProjectLinks"]
        {
          "@context" => links_context,
        }.merge(
          @json["Package"]["Project"]["ProjectLinks"]
        )
      else
        {}
      end
    end

    #
    # Prefixes
    #
    def prefixes
      {
        # "obo" => "http://purl.obolibrary.org/obo/",
        # "rdf" => "http://www.w3.org/1999/02/22-rdf-syntax-ns#",
        "bao" => "http://www.bioassayontology.org/bao#",
        "biocow" => "http://bio.cow/",
        "dcterms" => "http://purl.org/dc/terms/",
        "ddbj-tax" => "http://ddbj.nig.ac.jp/ontologies/taxonomy/",
        "foaf" => "http://xmlns.com/foaf/0.1/",
        "pav" => "http://purl.org/pav/",
        "rdfs" => "http://www.w3.org/2000/01/rdf-schema#",
        "schema" => "http://schema.org/",
        "sio" => "http://semanticscience.org/resource/",
        "xsd" => "http://www.w3.org/2001/XMLSchema#",
        "skos" => "http://www.w3.org/2004/02/skos/core#",
      }
    end

    #
    # BioProject Entry Properties
    #
    def bioproject_uri
      "http://identifiers.org/bioproject/#{@id}"
    end

    def bioproject_entry_type
      "biocow:BioProject"
    end

    def bioproject_context
      prefixes.merge(
        {
          "@version" => 1.1,
          "URI" => "@id",
          "entry_type" => "@type",
          "label" => "rdfs:label",
          "identifier" => "dcterms:identifier",
          "Submission" => "biocow:hasSubmission",
          "Project" => "biocow:hasProject",
          "ProjectLinks" => "biocow:hasLinks",
        }
      )
    end

    #
    # BioProject Submission Properties
    #
    def submission_context
      {
        "submitted" => {
          "@id" => "dcterms:dateSubmitted",
          "@type" => "xsd:dateTime",
        },
        "last_update" => {
          "@id" => "dcterms:modified",
          "@type" => "xsd:dateTime",
        },
        "Description" => "@nest",
        "Access" => "biocow:access", # "dcterms:accessRights" is ObjectProperty
        "Organization" => {
          "@id" => "pav:authoredBy",
          "@context" => {
            # will be update
            # "Name" => "@nest",
            # "$" => "rdfs:label",
            # "attr" => "skos:altLabel",
            "Name" => "rdfs:label",
            "role" => "biocow:role", # sio:SIO_000228 is ObjectProperty 'has role'
            "type" => "biocow:organization_type",
            "url" => "foaf:homepage",
          },
        },
      }
    end

    #
    # BioProject Project Properties
    #
    def project_context
      {
        # /Project/ProjectID
        "ProjectID" => "@nest",
        # /Project/ProjectID/ArchiveID
        "ArchiveID" => "@nest",
        "archive" => "pav:providedBy",
        "id" => "biocow:archive_id",
        "accession" => "dcterms:identifier",
        # /Project/ProjectID/ProjectDescr
        "ProjectDescr" => "@nest",
        "Title" => "dcterms:title",
        "Description" => "dcterms:description",
        "ProjectReleaseDate" => {
          "@id" => "dcterms:available",
          "@type" => "xsd:dateTime",
        }
        # /Project/ProjectID/ProjectType
        # Ignore so far
      }
    end

    #
    # BioProject ProjectLinks Properties
    #
    def links_context
      {
        "Link" => "@nest",
        "Hierarchical" => {
          "@id" => "biocow:hierarchicalLink",
          "@context" => {
            "type" => "biocow:linkType",
            "MemberID" => {
              "@id" => "biocow:members",
              "@context" => {
                "archive" => "pav:providedBy",
                "id" => "biocow:archive_id",
                "accession" => "dcterms:identifier",
              },
            }
          },
        },
        "ProjectIDRef" => {
          "@id" => "biocow:projectId",
          "@context" => {
            "archive" => "pav:providedBy",
            "id" => "biocow:archive_id",
            "accession" => "dcterms:identifier",
          },
        },
      }
    end

  end
end

if __FILE__ == $0
  endpoint_url = "52.199.195.71"
  PunkAPI.endpoint_url = endpoint_url

  # ids = [
  #   "PRJDB4503",
  #   "PRJNA13011",
  #   "PRJNA215990",
  #   "PRJEB6637",
  #   "PRJNA260331",
  # ]
  ids = JSON.load(open("http://" + endpoint_url + "/api/bioproject?term=lake%20water"))["ids"]

  ids.each do |id|
    bp = LDSRA::BioProject.new(id)
    case ARGV.first
    when "turtle"
      puts LDSRA.jsonld_to_turtle(bp.jsonld, bp.prefixes)
    when "json"
      puts JSON.pretty_generate(bp.json)
    when "jsonld"
      puts JSON.pretty_generate(bp.jsonld)
    end
  end
end
