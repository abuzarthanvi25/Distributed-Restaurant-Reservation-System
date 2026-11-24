package it.unipi.dsmt.gatherseatweb.servlet;

import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.*;
import java.io.IOException;
import java.util.Map;
import java.util.UUID;

@WebServlet("/dev-login")
public class DevLoginServlet extends HttpServlet {
    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse resp) throws IOException {
        HttpSession s = req.getSession(true);
        s.setAttribute("user", Map.of("id", 1, "name", "Dev User", "role", "CUSTOMER"));
        s.setAttribute("csrfToken", UUID.randomUUID().toString());
        resp.sendRedirect(req.getContextPath() + "/restaurants.jsp");
    }
}