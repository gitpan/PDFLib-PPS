package PDFLib::PPS;

use strict;
use base 'PDFLib';
use pdflib_pl 7.0;

use constant { ERROR => -1 };

our $VERSION = '0.01';

sub new {
  my $class = shift;
  my $pdf = $class->SUPER::new(@_);
  return $pdf;
}

sub search_path {
  my ($pdf, $search_path) = @_;
  if (defined $search_path) {
    $pdf->{SearchPath} = $search_path;
  }
  $pdf->{SearchPath};
}

sub block_data {
  my $pdf = shift;
  if ($_[0]) {
    $pdf->{BlockData} = ref $_[0] ? $_[0] : \@_;
  }
  return $pdf->{BlockData};
}

sub block_datum {
  my ($pdf, $block_name, $value) = @_;
  if (defined $value) {
    $pdf->{BlockData}->{$block_name} = $value;
  }
  return $pdf->{BlockData}->{$block_name};
}

sub block_container {		# this is the "template" filename
  my ($pdf, $block_container) = @_;
  if (defined $block_container) {
    $pdf->{BlockContainer} = $block_container;
  }
  $pdf->{BlockContainer};
}

sub container {			# i.e., the block container object
  my ($pdf, $container) = @_;
  if (defined $container) {
    $pdf->{container} = $container;
  }
  return $pdf->{container};
}

sub current_page {
  my ($pdf, $page) = @_;
  if (defined $page) {
    $pdf->{page} = $page;
  }
  return $pdf->{page};
}


sub fill_in {
  my $pdf = shift;

  my $container = $pdf->open_pdi_document;
  defined $container ? $pdf->container($container) : return undef;

  for my $page_no (1 .. $pdf->number_of_pages) {

    # open the template page.
    my $page = $pdf->open_pdi_page($page_no);
    defined $page ? $pdf->current_page($page) : return undef;

    # create a new document page.
    $pdf->begin_page_ext;

    for my $block_name ($pdf->block_names) {
      my $encoding = $pdf->encoding_for_block($block_name);
      my $fill = PDF_fill_textblock($pdf->_pdf, $pdf->current_page, 
				    $block_name, $pdf->block_datum($block_name),
				    $encoding);
      if ($fill == ERROR) { return undef }
    }
    
    $pdf->end_page_ext;
    $pdf->close_pdi_page;
  }

  $pdf->close_pdi_document;
  return "OK";
}

sub end_page_ext {
  my $pdf = shift;
  PDF_end_page_ext($pdf->_pdf, "");
}

sub begin_page_ext {
  my $pdf = shift;
  PDF_begin_page_ext($pdf->_pdf, 20, 20, "");
  PDF_fit_pdi_page($pdf->_pdf, $pdf->current_page, 0, 0, "adjustpage");
}

sub encoding_for_block { 
  my ($pdf, $block_name) = @_;
  my $font = $pdf->font_for_block($block_name);
  if ($font eq 'ZapfDingbats') {
    return "encoding=builtin";
  }
  else {
    return "encoding=host";
  }
}

sub font_for_block {
  my ($pdf, $block_name) = @_;
  my $font = 
    PDF_get_pdi_parameter($pdf->_pdf, "vdp/Blocks/$block_name/fontname",
			  $pdf->container, $pdf->current_page, 0);
  return $font;
}

sub block_names {
  my $pdf = shift;
  my $count = $pdf->block_count;
  return map { PDF_get_pdi_parameter($pdf->_pdf, "vdp/Blocks[$_]/Name",
				   $pdf->container, $pdf->current_page, 0) }
    (0 .. ($pdf->block_count - 1));
}

sub block_count {
  my $pdf = shift;
  return PDF_get_pdi_value($pdf->_pdf, 'vdp/blockcount', 
			   $pdf->container, $pdf->current_page, 0);
}

sub number_of_pages {
  my $pdf = shift;
  return PDF_get_pdi_value($pdf->_pdf, '/Root/Pages/Count',
			   $pdf->container, -1, 0);
}

sub open_pdi_document {
  my ($pdf) = @_;
  $pdf->set_parameter(SearchPath => $pdf->search_path);
  $pdf->set_parameter(pdiwarning => 'true');
  my $container = PDF_open_pdi_document($pdf->_pdf, $pdf->block_container, "");
  if ($container == ERROR) {
    warn ("Error opening PDI document: ", PDF_get_errmsg($pdf->_pdf));
    return undef;
  }
  return $container;
}

sub close_pdi_document {
  my $pdf = shift;
  PDF_close_pdi($pdf->_pdf, $pdf->container);
}

sub open_pdi_page {
  my ($pdf, $page_no) = @_;
  my $page = PDF_open_pdi_page($pdf->_pdf, $pdf->container, $page_no, "");
  if ($page == ERROR) {
    warn ("Error opening PDI page: ", PDF_get_errmsg($pdf->_pdf));
    return undef;
  }
  return $page;
}

sub close_pdi_page {
  my $pdf = shift;
  PDF_close_pdi_page($pdf->_pdf, $pdf->current_page);
}


1;


__END__

=head1 NAME
  
  PDFLib::PPS -- PDFLib Personalization Server OO Interface

=head1 SYNOPSIS

  use PDFLib::PPS;
  
  my $search_path = "$FindBin::Bin/../data";
  my $template    = "boilerplate.pdf";
  
  my %data = ("name"                      => "Victor Kraxi",
              "business.title"            => "Chief Paper Officer",
              "business.address.line1"    => "17, Aviation Road",
              "business.address.city"     => "Paperfield",
              "business.telephone.voice"  => "phone +1 234 567-89",
              "business.telephone.fax"    => "fax +1 234 567-98",
              "business.email"            => "victor\@kraxi.com",
  	      "business.homepage"         => "www.kraxi.com"
  	    );
  
  my $pdf = PDFLib::PPS->new(filename	    => "/tmp/business.pdf",
  			     SearchPath	    => $search_path,
  			     BlockContainer => $template,
  			     BlockData	    => \%data);
  
  $pdf->fill_in or die "unable to fill in the block container";


=head1 DESCRIPTION

PDFLib::PPS is a convenience wrapper/OO interface around the PDFlib
Personalization Service.  See www.pdflib.com for info about the PPS.

The goal is to be able to associate some key/value pairs with a
template (i.e., a "Block Container") and end up with a PDF.  

=head1 BASIC METHODS

=head2 new(...)

The object creation is delegated to PDFLib; see the PDFLib perldoc for
details.  There are three additional parameters which might be useful:
SearchPath (which is then set as the SearchPath parameter),
BlockContainer (the PDF document with the named blocks defined within,
maybe well thought of as a 'template'), and BlockData (a hashref of
block-name => block-text pairs).

=head2 fill_in()

Shoves BlockData into the BlockContainer specified.  Returns undef on
error or the string "OK" upon success.  

=head1 GET/SET Methods

=head2 search_path([new path])

Get/Set the SearchPath parameter.

=head2 block_data([data hashref])

Get/Set the BlockData.

=head2 block_datum(key, [new value])

Get/Set the named BlockData datum.

=head2 block_container([new block container])

Get/Set the BlockContainer.



=head1 INTERNAL METHODS

NB: "Objects" here are whatever the PDFlib bindings require in PDF_*
subroutines.  I suspect that these are not actual objects, but it
doesn't really matter.

=head2 container([container])

Get/Set the current container "object"

=head2 current_page([page])

Get/Set the current page "object"

=head2 begin_page_ext()

Calls both PDF_being_page_ext and PDF_fit_pdi_page.  The geometry will
be adjusted to fit the imported block container.

=head2 end_page_ext()

Calls PDF_end_page_ext.

=head2 open_pdi_document()

Sets the SearchPath and attempts to open BlockContainer with
PDF_open_pdi_document.  Returns undef on failure or the container
"object" upon success.  This "object" is suitable for sending to
container(), above.

=head2 close_pdi_document()

Calls PDF_close_pdi.  Note these subroutines are not identically named.

=head2 open_pdi_page(page number)

Calls PDF_open_pdi_page.  Returns undef on failure, and the page
"object" upon success.  This "object" is suitable for sending to
current_page(), above.

=head2 close_pdi_page()

Calls PDF_close_pdi_page.

=head2 number_of_pages()

Returns the number of pages in the container (which must have been set).

=head2 block_count()

Returns the number of blocks on the container's current page.  Both
container and current_page must be set.

=head2 block_names() 

Returns a list of the block names on the container's current page.
Both container and current_page must be set.

=head2 font_for_block(block name)

Returns the text string naming the font to be used for the specified
block.  Block name must exist, container and current_page must be set.

=head2 encoding_for_block(block name)

A wicked hack.  Returns a string suitable for the last argument in
PDF_fill_textblock, so long as the font for the named block is
Helvetica or ZapfDingbats.  For other fonts it's a crapshoot as yet.

=head1 BUGS

No doubt, and only the text fillin method is supported as yet.  I only
have access to a couple of PDF BlockContainers and this code works
reliably for those.  Without Acrobat I'm unable to drum up more test
cases.

=head1 AUTHOR

  Kevin Montuori <cpan@mconsultancy.us>
  August 2007








