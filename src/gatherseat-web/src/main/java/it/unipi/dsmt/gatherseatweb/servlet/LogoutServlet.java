package it.unipi.dsmt.gatherseatweb.servlet;

import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.*;
import java.io.IOException;
import java.util.Map;
import java.util.UUID;

@WebServlet("/logout")
public class LogoutServlet extends HttpServlet {
    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse resp) throws IOException {
        HttpSession s = req.getSession(true);
        s.removeAttribute("user");
        s.removeAttribute("csrfToken");
        s.invalidate();
        resp.sendRedirect(req.getContextPath() + "/");
    }
}