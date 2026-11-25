
package it.unipi.dsmt.gatherseatweb.model;

public class Restaurant {

    private Long id;
    private String name;
    private String description;
    private String address;
    private String city;
    private String cuisine;

    public Restaurant() {
    }

    public Restaurant(
            Long id,
            String name,
            String description,
            String address,
            String city,
            String cuisine
    ) {
        this.id = id;
        this.name = name;
        this.description = description;
        this.address = address;
        this.city = city;
        this.cuisine = cuisine;
    }

    public Long getId() {
        return id;
    }

    public String getName() {
        return name;
    }

    public String getDescription() {
        return description;
    }

    public String getAddress() {
        return address;
    }

    public String getCity() {
        return city;
    }

    public String getCuisine() {
        return cuisine;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public void setName(String name) {
        this.name = name;
    }

    public void setDescription(String description) {
        this.description = description;
    }

    public void setAddress(String address) {
        this.address = address;
    }

    public void setCity(String city) {
        this.city = city;
    }

    public void setCuisine(String cuisine) {
        this.cuisine = cuisine;
    }
}
