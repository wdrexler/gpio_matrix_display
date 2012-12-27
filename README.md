gpio_matrix_display
===================

A Ruby clone of MilesBurton's MatrixDisplay using GPIO for Raspberry Pi


Examples
===================

Scrolling Text
--------------

    require '/path/to/text_display'
    
    #Initialize 1 display with clock pin 14, data pin 15, and display pin 17
    text_display = TextDisplay.new 1, 14, 15, [17]

    #Now, make your text scroll with a 200ms delay between steps
    text_display.scroll_text "Hiya there", 200
