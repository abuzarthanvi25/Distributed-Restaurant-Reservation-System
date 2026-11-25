
package it.unipi.dsmt.gatherseatweb.servlet;

import com.google.gson.Gson;
import it.unipi.dsmt.gatherseatweb.dto.ApiResponse;

import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

import java.io.IOException;
import java.util.UUID;

@WebServlet("/api/health")
public class HealthServlet extends HttpServlet {

    private final Gson gson = new Gson();

    @Override
    protected void doGet(
            HttpServletRequest request,
            HttpServletResponse response
    ) throws IOException {

        String requestId = UUID.randomUUID().toString();

        ApiResponse<String> result = ApiResponse.success(
                "GatherSeat is running",
                requestId,
                "OK"
        );

        response.setStatus(HttpServletResponse.SC_OK);
        response.setContentType("application/json");
        response.setCharacterEncoding("UTF-8");

        response.getWriter().write(gson.toJson(result));
    }
}
