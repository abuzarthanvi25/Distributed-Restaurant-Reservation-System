package it.unipi.dsmt.gatherseatweb.servlet;

import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.*;
import java.io.IOException;
import java.util.Map;
import java.util.UUID;

@WebServlet("/login")
public class LoginServlet extends HttpServlet {
    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse resp) throws IOException {
        HttpSession s = req.getSession(true);
        s.setAttribute("user", Map.of("id", 1, "name", "Dev User", "role", "ADMIN"));
        s.setAttribute("csrfToken", UUID.randomUUID().toString());
        resp.sendRedirect(req.getContextPath() + "/restaurants.jsp");
    }
}