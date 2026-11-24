
package it.unipi.dsmt.gatherseatweb.servlet;

import com.google.gson.Gson;

import it.unipi.dsmt.gatherseatweb.dto.ApiResponse;
import it.unipi.dsmt.gatherseatweb.model.Restaurant;

import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

import java.io.IOException;
import java.util.List;
import java.util.UUID;

@WebServlet("/api/restaurants")
public class RestaurantServlet extends HttpServlet {

    private final Gson gson = new Gson();

    // Temporary sample data.
    // Later this will come from the database.
    private final List<Restaurant> restaurants = List.of(
            new Restaurant(
                    1L,
                    "La Pergoletta",
                    "Traditional Italian restaurant",
                    "Via delle Belle Torri 36",
                    "Pisa",
                    "Italian"
            ),
            new Restaurant(
                    2L,
                    "Osteria dei Cavalieri",
                    "Traditional Tuscan cuisine",
                    "Via San Frediano 16",
                    "Pisa",
                    "Tuscan"
            ),
            new Restaurant(
                    3L,
                    "Pizzeria Pisa",
                    "Pizza and Mediterranean dishes",
                    "Piazza Dante 5",
                    "Pisa",
                    "Pizza"
            )
    );

    @Override
    protected void doGet(
            HttpServletRequest request,
            HttpServletResponse response
    ) throws IOException {

        String requestId = UUID.randomUUID().toString();

        ApiResponse<List<Restaurant>> result = ApiResponse.success(
                "Restaurants retrieved successfully",
                requestId,
                restaurants
        );

        response.setStatus(HttpServletResponse.SC_OK);
        response.setContentType("application/json");
        response.setCharacterEncoding("UTF-8");

        response.getWriter().write(gson.toJson(result));
    }
}
