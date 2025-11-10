namespace LouveSystems.K2
{
    using LouveSystems.K2.Lib;
    using System;
    using System.Collections.Generic;
    using System.Drawing;
    using System.IO;

    public static class GameStateDrawer
    {
        private static readonly Color[] playerColors = new Color[] {
            Color.FromArgb(230, 25, 75),
            Color.FromArgb(60, 180, 75),
            Color.FromArgb(255, 225, 25),
            Color.FromArgb(0, 130, 200),
            Color.FromArgb(245, 130, 48),
            Color.FromArgb(70, 240, 240),
            Color.FromArgb(240, 50, 230),
            Color.FromArgb(250, 190, 212),
            Color.FromArgb(0, 128, 128),
            Color.FromArgb(220, 190, 255),
            Color.FromArgb(170, 110, 40),
            Color.FromArgb(255, 250, 200),
            Color.FromArgb(128, 0, 0),
            Color.FromArgb(170, 255, 195),
            Color.FromArgb(0, 0, 128),
            Color.FromArgb(128, 128, 128),
            Color.FromArgb(255, 255, 255),
            Color.FromArgb(0, 0, 0)
        };

        public static void Draw(GameState state, out Bitmap bitmap)
        {
            Bitmap bmp = new Bitmap(512, 512);

            Graphics g = Graphics.FromImage(bmp);

            Pen backgroundPen = new Pen(Color.White);

            g.FillRectangle(backgroundPen.Brush, new Rectangle(0, 0, bmp.Width, bmp.Height));

            DrawHexGrid(g, bmp.Width, state);

            bitmap = bmp;
        }

        private static void DrawHexGrid(Graphics gr, float pixelSquareSize, in GameState state)
        {
            Pen strokePen = new Pen(Color.Black);
            Pen fillPen = new Pen(Color.White);
            float size = (pixelSquareSize / (state.world.SideLength + 1.73f));
            float height = size;
            float width = HexWidth(height);

            StringFormat format = new StringFormat() {
                Alignment = StringAlignment.Center,
                LineAlignment = StringAlignment.Center
            };

            List<PointF> centers = new List<PointF>();

            for (int i = 0; i < state.world.Regions.Count; i++) {

                if (!state.world.Regions[i].inert) {
                    var position = state.world.Position(i);

                    PointF[] points = HexToPoints(height, position.x, position.y);

                    if (state.world.Regions[i].GetOwner(out byte regionOwner)) {
                        if (state.world.IsCouncilRegion(i)) {
                            fillPen.Color = playerColors[playerColors.Length - 1];
                        }
                        else {
                            fillPen.Color = playerColors[regionOwner];
                        }
                    }
                    else {
                        fillPen.Color = Color.White;
                    }

                    centers.Add(new PointF((points[0].X + points[3].X) / 2, (points[0].Y + points[3].Y) / 2));

                    gr.FillPolygon(fillPen.Brush, points);
                    gr.DrawPolygon(strokePen, points);
                }
                else {
                    centers.Add(default);
                }
            }

            for (int i = 0; i < state.world.Regions.Count; i++) {

                var position = state.world.Position(i);
                if (!state.world.Regions[i].inert) {

                    if (state.world.Regions[i].buildings != EBuilding.None) {
                        string str = string.Empty;

                        switch (state.world.Regions[i].buildings) {
                            case EBuilding.Capital:
                                str = "⭐";
                                break;

                            case EBuilding.Church:
                                str = "⛪";
                                break;

                            case EBuilding.Fields:
                                str = "🌽";
                                break;

                            case EBuilding.Fort:
                                str = "🏰";
                                break;
                        }

                        if (string.IsNullOrEmpty(str)) {
                            // Do nothing
                        }
                        else {
                            if (state.world.Regions[i].buildings == EBuilding.Capital) {

                                gr.DrawString(
                                    str,
                                    new Font("Segoe UI Emoji", 10),
                                    Brushes.Black,
                                    centers[i],
                                    format
                                );

                                gr.DrawString(
                                    $"#{state.world.Regions[i].ownerIndex}",
                                    new Font(FontFamily.GenericSerif, 14),
                                    Brushes.Black,
                                    new PointF(centers[i].X, centers[i].Y - 10f),
                                    format
                                );
                            }
                            else {
                                gr.DrawString(
                                    str,
                                    new Font("Segoe UI Emoji", 10),
                                    Brushes.Black,
                                    centers[i],
                                    format
                                );
                            }
                        }
                    }
                }

                gr.DrawString(
                    i.ToString(),
                    new Font(FontFamily.GenericMonospace, 8),
                    Brushes.DarkGray,
                    new PointF(centers[i].X, centers[i].Y + 10),
                    format
                );
            }
        }

        // Draw the indicated star in the rectangle.
        private static void DrawStar(Graphics gr, Pen the_pen, Brush the_brush,
            int num_points, int skip, RectangleF rect)
        {
            // Get the star's points.
            PointF[] star_points =
                MakeStarPoints(-Math.PI / 2, num_points, skip, rect);

            // Draw the star.
            gr.FillPolygon(the_brush, star_points);
            gr.DrawPolygon(the_pen, star_points);
        }

        // Generate the points for a star.
        private static PointF[] MakeStarPoints(double start_theta,
            int num_points, int skip, RectangleF rect)
        {
            double theta, dtheta;
            PointF[] result;
            float rx = rect.Width / 2f;
            float ry = rect.Height / 2f;
            float cx = rect.X + rx;
            float cy = rect.Y + ry;

            // If this is a polygon, don't bother with concave points.
            if (skip == 1) {
                result = new PointF[num_points];
                theta = start_theta;
                dtheta = 2 * Math.PI / num_points;
                for (int i = 0; i < num_points; i++) {
                    result[i] = new PointF(
                        (float)(cx + rx * Math.Cos(theta)),
                        (float)(cy + ry * Math.Sin(theta)));
                    theta += dtheta;
                }
                return result;
            }

            // Find the radius for the concave vertices.
            double concave_radius =
                CalculateConcaveRadius(num_points, skip);

            // Make the points.
            result = new PointF[2 * num_points];
            theta = start_theta;
            dtheta = Math.PI / num_points;
            for (int i = 0; i < num_points; i++) {
                result[2 * i] = new PointF(
                    (float)(cx + rx * Math.Cos(theta)),
                    (float)(cy + ry * Math.Sin(theta)));
                theta += dtheta;
                result[2 * i + 1] = new PointF(
                    (float)(cx + rx * Math.Cos(theta) * concave_radius),
                    (float)(cy + ry * Math.Sin(theta) * concave_radius));
                theta += dtheta;
            }
            return result;
        }
        // Calculate the inner star radius.
        private static double CalculateConcaveRadius(int num_points, int skip)
        {
            // For really small numbers of points.
            if (num_points < 5) return 0.33f;

            // Calculate angles to key points.
            double dtheta = 2 * Math.PI / num_points;
            double theta00 = -Math.PI / 2;
            double theta01 = theta00 + dtheta * skip;
            double theta10 = theta00 + dtheta;
            double theta11 = theta10 - dtheta * skip;

            // Find the key points.
            PointF pt00 = new PointF(
                (float)Math.Cos(theta00),
                (float)Math.Sin(theta00));
            PointF pt01 = new PointF(
                (float)Math.Cos(theta01),
                (float)Math.Sin(theta01));
            PointF pt10 = new PointF(
                (float)Math.Cos(theta10),
                (float)Math.Sin(theta10));
            PointF pt11 = new PointF(
                (float)Math.Cos(theta11),
                (float)Math.Sin(theta11));

            // See where the segments connecting the points intersect.
            bool lines_intersect, segments_intersect;
            PointF intersection, close_p1, close_p2;
            FindIntersection(pt00, pt01, pt10, pt11,
                out lines_intersect, out segments_intersect,
                out intersection, out close_p1, out close_p2);

            // Calculate the distance between the
            // point of intersection and the center.
            return Math.Sqrt(
                intersection.X * intersection.X +
                intersection.Y * intersection.Y);
        }
        private static void FindIntersection(
    PointF p1, PointF p2, PointF p3, PointF p4,
    out bool lines_intersect, out bool segments_intersect,
    out PointF intersection,
    out PointF close_p1, out PointF close_p2)
        {
            // Get the segments' parameters.
            float dx12 = p2.X - p1.X;
            float dy12 = p2.Y - p1.Y;
            float dx34 = p4.X - p3.X;
            float dy34 = p4.Y - p3.Y;

            // Solve for t1 and t2
            float denominator = (dy12 * dx34 - dx12 * dy34);

            float t1 =
                ((p1.X - p3.X) * dy34 + (p3.Y - p1.Y) * dx34)
                    / denominator;
            if (float.IsInfinity(t1)) {
                // The lines are parallel (or close enough to it).
                lines_intersect = false;
                segments_intersect = false;
                intersection = new PointF(float.NaN, float.NaN);
                close_p1 = new PointF(float.NaN, float.NaN);
                close_p2 = new PointF(float.NaN, float.NaN);
                return;
            }
            lines_intersect = true;

            float t2 =
                ((p3.X - p1.X) * dy12 + (p1.Y - p3.Y) * dx12)
                    / -denominator;

            // Find the point of intersection.
            intersection = new PointF(p1.X + dx12 * t1, p1.Y + dy12 * t1);

            // The segments intersect if t1 and t2 are between 0 and 1.
            segments_intersect =
                ((t1 >= 0) && (t1 <= 1) &&
                 (t2 >= 0) && (t2 <= 1));

            // Find the closest points on the segments.
            if (t1 < 0) {
                t1 = 0;
            }
            else if (t1 > 1) {
                t1 = 1;
            }

            if (t2 < 0) {
                t2 = 0;
            }
            else if (t2 > 1) {
                t2 = 1;
            }

            close_p1 = new PointF(p1.X + dx12 * t1, p1.Y + dy12 * t1);
            close_p2 = new PointF(p3.X + dx34 * t2, p3.Y + dy34 * t2);
        }

        // Return the points that define the indicated hexagon.
        private static PointF[] HexToPoints(float height, float row, float col)
        {
            // Start with the leftmost corner of the upper left hexagon.
            float width = HexWidth(height);
            float y = height / 2;
            float x = 0;

            // Move down the required number of rows.
            y += row * height;

            // If the column is odd, move down half a hex more.
            if (col % 2 == 1) y += height / 2;

            // Move over for the column number.
            x += col * (width * 0.75f);

            // Generate the points.
            return new PointF[]
                {
            new PointF(x, y),
            new PointF(x + width * 0.25f, y - height / 2),
            new PointF(x + width * 0.75f, y - height / 2),
            new PointF(x + width, y),
            new PointF(x + width * 0.75f, y + height / 2),
            new PointF(x + width * 0.25f, y + height / 2),
                };
        }

        // Return the width of a hexagon.
        private static float HexWidth(float height)
        {
            return (float)(4 * (height / 2 / Math.Sqrt(3)));
        }
    }
}
